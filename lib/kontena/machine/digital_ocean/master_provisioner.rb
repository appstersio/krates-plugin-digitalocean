require 'fileutils'
require 'erb'
require 'open3'
require 'json'

module Kontena
  module Machine
    module DigitalOcean
      class MasterProvisioner
        include RandomName
        include Machine::CertHelper
        include Kontena::Cli::ShellSpinner

        attr_reader :client, :http_client

        # @param [String] token Digital Ocean token
        def initialize(token)
          @client = DropletKit::Client.new(access_token: token)
        end

        def run!(opts)
          abort('Invalid ssh key') unless File.exists?(File.expand_path(opts[:ssh_key]))

          ssh_key = ssh_key(File.read(File.expand_path(opts[:ssh_key])).strip)
          abort('Ssh key does not exist in Digital Ocean') unless ssh_key

          if opts[:ssl_cert]
            abort('Invalid ssl cert') unless File.exists?(File.expand_path(opts[:ssl_cert]))
            ssl_cert = File.read(File.expand_path(opts[:ssl_cert]))
          else
            spinner "Generating a self-signed SSL certificate" do
              ssl_cert = generate_self_signed_cert
            end
          end

          name = generate_name
          userdata_vars = opts.merge(
              ssl_cert: ssl_cert,
              server_name: name.sub('kontena-master-', '')
          )

          droplet = DropletKit::Droplet.new(
              name: name,
              region: opts[:region],
              image: 'coreos-stable',
              size: opts[:size],
              private_networking: true,
              user_data: user_data(userdata_vars),
              ssh_keys: [ssh_key.id]
          )

          spinner "Creating a DigitalOcean droplet #{droplet.name.colorize(:cyan)} " do
            droplet = client.droplets.create(droplet)
            until droplet.status == 'active'
              droplet = client.droplets.find(id: droplet.id)
              sleep 1
            end
          end

          master_url = "https://#{droplet.public_ip}"
          Excon.defaults[:ssl_verify_peer] = false
          @http_client = Excon.new("#{master_url}", :connect_timeout => 10)

          spinner "Waiting for #{droplet.name.colorize(:cyan)} to start" do
            sleep 0.5 until master_running?
          end

          master_version = nil
          spinner "Retrieving Kontena Master version" do
            master_version = JSON.parse(http_client.get(path: '/').body)["version"] rescue nil
          end

          spinner "Kontena Master #{master_version} is now running at #{master_url}".colorize(:green)


          {
            name: name.sub('kontena-master-', ''),
            public_ip: droplet.public_ip,
            provider: 'digitalocean',
            version: master_version,
            code: opts[:initial_admin_code]
          }
        end

        def user_data(vars)
          cloudinit_template = File.join(__dir__ , '/cloudinit_master.yml')
          erb(File.read(cloudinit_template), vars)
        end

        def generate_name
          "kontena-master-#{super}-#{rand(1..9)}"
        end

        def ssh_key(public_key)
          client.ssh_keys.all.find{|key| key.public_key == public_key}
        end

        def master_running?
          http_client.get(path: '/').status == 200
        rescue
          false
        end

        def erb(template, vars)
          ERB.new(template, nil, '%<>-').result(OpenStruct.new(vars).instance_eval { binding })
        end
      end
    end
  end
end
