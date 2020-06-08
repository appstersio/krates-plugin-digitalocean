# Always use this form to avoid ordering/layering issues with Ruby interpeter
# eq. module is referenced before being declared/initialized.
module Kontena
  module Plugin
    module DigitalOcean
      module Prompts

        # Until DO merges https://github.com/digitalocean/resource_kit/pull/32
        def suppress_warnings
          @original_verbosity = $VERBOSE
          $VERBOSE = nil
        end

        def resume_warnings
          $VERBOSE = @original_verbosity
        end

        def ask_ssh_key(do_token)
          manager = Kontena::Machine::DigitalOcean::SshKeyManager.new(do_token)

          if self.ssh_key
            public_key = File.read(self.ssh_key).strip
          else
            keys = manager.list
            key = :new

            default_path = File.join(Dir.home, '.ssh', 'id_rsa.pub')
            default = File.exist?(default_path) ? File.read(default_path).strip : nil

            unless keys.empty?
              key = prompt.select("Choose SSH key:") do |menu|
                i = 1
                keys.each do |item|
                  menu.choice "#{item.name} (#{item.fingerprint})" , item
                  menu.default i if item.public_key == default
                  i += 1
                end
                menu.choice "Create new SSH key", :new
              end
            end

            if key == :new

              public_key = prompt.ask('SSH public key: (enter an ssh key in OpenSSH format "ssh-xxx xxxxx key_name")', default: default) do |q|
                q.validate /^ssh-rsa \S+ \S+$/
              end
            else
              return key.id
            end
          end
          manager.find_or_create_by_public_key(public_key).id
        end

        def ask_do_token
          if self.token.nil?
            prompt.mask('DigitalOcean API token:')
          else
            self.token
          end
        end

        def ask_droplet_region(do_token)
          if self.region.nil?
            prompt.select("Choose a datacenter region:") do |menu|
              do_client = DropletKit::Client.new(access_token: do_token)
              do_client.regions.all.sort_by{|r| r.slug }.each{ |region|
                menu.choice region.name, region.slug
              }
            end
          else
            self.region
          end
        end

        def ask_droplet_size(do_token, do_region)
          if self.size.nil?
            prompt.select("Choose droplet size:") do |menu|
              do_client = DropletKit::Client.new(access_token: do_token)
              do_client.sizes.all.to_a.select{ |s| s.memory > 1000 }.sort_by{|s| s.memory }.each{ |size|
                #p size
                if size.regions.include?(do_region)
                  memory = size.memory.to_i / 1024
                  menu.choice "#{size.slug}: #{memory}GB/#{size.vcpus}CPU/#{size.disk}GB ($#{size.price_monthly.to_i}/mo)", size.slug
                end
              }
            end
          else
            self.size
          end
        end

        def ask_node(token)
          if self.name.nil?
            nodes = client(token).get("grids/#{current_grid}/nodes")
            nodes = nodes['nodes'].select{ |n|
              n['labels'] && n['labels'].include?('provider=digitalocean'.freeze)
            }
            raise "Did not find any nodes with label provider=digitalocean" if nodes.size == 0
            prompt.select("Select node:") do |menu|
              nodes.sort_by{|n| n['node_number'] }.reverse.each do |node|
                initial = node['initial_member'] ? '(initial) ' : ''
                menu.choice "#{node['name']} #{initial}", node['name']
              end
            end
          else
            self.name
          end
        end

        def ask_channel
          prompt.select('Select Container Linux channel:') do |menu|
            menu.choice 'Stable', 'stable'
            menu.choice 'Beta', 'beta'
            menu.choice 'Alpha', 'alpha'
          end
        end
      end
    end
  end
end
