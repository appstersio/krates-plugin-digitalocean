require 'fileutils'
require 'erb'
require 'open3'

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
          if opts[:ssl_cert]
            abort('Invalid ssl cert') unless File.exists?(File.expand_path(opts[:ssl_cert]))
            ssl_cert = File.read(File.expand_path(opts[:ssl_cert]))
          else
            spinner "Generating self-signed SSL certificate" do
              ssl_cert = generate_self_signed_cert
            end
          end

          name = opts[:name]
          userdata_vars = opts.merge(
              ssl_cert: ssl_cert,
              server_name: name
          )

          droplet = DropletKit::Droplet.new(
              name: name,
              region: opts[:region],
              image: 'coreos-stable',
              size: opts[:size],
              private_networking: true,
              user_data: user_data(userdata_vars),
              ssh_keys: [opts[:ssh_key_id]],
              tags: ['master']
          )

          spinner "Creating DigitalOcean droplet #{droplet.name.colorize(:cyan)} " do
            droplet = client.droplets.create(droplet)
            until droplet.status == 'active'
              droplet = client.droplets.find(id: droplet.id)
              sleep 1
            end
          end

          master_url = "https://#{droplet.public_ip}"
          Excon.defaults[:ssl_verify_peer] = false
          @http_client = Excon.new("#{master_url}", {
            :connect_timeout => 10,
            :ssl_verify_peer => false
          })

          spinner "Waiting for #{droplet.name.colorize(:cyan)} to start" do
            sleep 0.5 until master_running?
          end

          show_summary(master_url)

          data = {
            name: name.sub('kontena-master-', ''),
            public_ip: droplet.public_ip,
            code: opts[:initial_admin_code]
          }
          if respond_to?(:certificate_public_key) && !opts[:ssl_cert]
            data[:ssl_certificate] = certificate_public_key(ssl_cert)
          end

          data
        end

        def user_data(vars)
          cloudinit_template = File.join(__dir__ , '/cloudinit_master.yml')
          erb(File.read(cloudinit_template), vars)
        end

        def master_running?
          http_client.get(path: '/').status == 200
        rescue
          false
        end

        def erb(template, vars)
          # Trim mode has changed, here is how: https://redmine.ruby-lang.org/attachments/7457?utf8=✓&type=sbs
          ERB.new(template, nil, '-').result(OpenStruct.new(vars).instance_eval { binding })
        end

        def show_summary(master_url)
          puts
          puts "Krates Master is now running at #{master_url}".colorize(:green)
          puts
        end
      end
    end
  end
end
