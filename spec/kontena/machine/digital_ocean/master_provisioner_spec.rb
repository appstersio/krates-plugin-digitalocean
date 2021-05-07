require 'kontena/machine/digital_ocean'

# NOTE: This test suite relies heavily and only on the naive string match,
# so if it ever turns red use simple string search as the main troubleshooting utility.
# Godspeed. 
describe Kontena::Machine::DigitalOcean::MasterProvisioner do

  let(:subject) do
    described_class.new('token')
  end

  let(:client) { double(:client) }

  let(:droplets) { double(:droplets) }

  before do
    # intercept and supress spinner output, so that test output looks clean + useful
    allow(subject).to receive(:spinner) do |msg, &block|
      block.call
    end
    # stub these methods so that we can validate
    allow(client).to receive(:droplets).and_return(droplets)
    allow(subject).to receive(:client).and_return(client)
    allow(subject).to receive(:show_summary).and_return(spy)
  end

  describe '#run!' do
    context 'master' do
      # Captures droplet details to be sent to DigitalOcean
      droplet, data = nil, nil

      before do
        # stub so that it appears as if master were up & running
        allow(subject).to receive(:master_running?).and_return(true)
        # intercept and modify droplet attributes as if it was successfully created
        allow(droplets).to receive(:create) do |d|
          droplet = d
          allow(d).to receive(:public_ip).and_return('127.0.0.1')
          d.status = 'active'
          d
        end
        # run provisioner and capture its output for further inspection
        data = subject.run!(:name => 'xoxo')
      end

      it "uses latest 'quay.io/krates/master' image" do
        expect(droplet.user_data).to include('- name: krates-server-api.service')
        expect(droplet.user_data).to include('quay.io/krates/master')
        expect(droplet.user_data).to include('ExecStart=/usr/bin/docker run --name kontena-server-api \\')
      end

      it "stops existing 'quay.io/krates/master' container at stop" do
        expect(droplet.user_data).to include('ExecStop=/usr/bin/docker stop kontena-server-api')
      end

      it "stops and removes existing 'quay.io/krates/master' container at pre-start" do
        expect(droplet.user_data).to include('ExecStartPre=-/usr/bin/docker stop kontena-server-api')
        expect(droplet.user_data).to include('ExecStartPre=-/usr/bin/docker rm kontena-server-api')
      end

      it "has expected 'master' unit description" do
        expect(droplet.user_data).to include('Description=krates-server-api')
        expect(droplet.user_data).to include('Description=Krates Master')
        expect(droplet.user_data).to include('Documentation=https://github.com/appstersio/krates/')
      end

      it "uses latest 'krates/haproxy' image" do
        expect(droplet.user_data).to include('- path: /opt/bin/krates-haproxy.sh')
        expect(droplet.user_data).to include('/usr/bin/docker run --name=krates-server-haproxy')
        expect(droplet.user_data).to include('-p 80:80 -p 443:443 krates/haproxy:latest')
        expect(droplet.user_data).to include('- name: krates-server-haproxy.service')
      end

      it 'has expected unit description' do
        expect(droplet.user_data).to include('Description=krates-server-haproxy')
        expect(droplet.user_data).to include('Description=Krates Server HAProxy')
      end

      it 'stops and removes existing container at pre-start' do
        expect(droplet.user_data).to include('ExecStartPre=-/usr/bin/docker stop krates-server-haproxy')
        expect(droplet.user_data).to include('ExecStartPre=-/usr/bin/docker rm krates-server-haproxy')
      end

      it 'always pulls the latest image at pre-start' do
        expect(droplet.user_data).to include('ExecStartPre=-/usr/bin/docker pull krates/haproxy:latest')
      end

      it 'launches shell wrapper at start' do
        expect(droplet.user_data).to include('ExecStart=/opt/bin/krates-haproxy.sh')
      end

      it 'stops existing container at stop' do
        expect(droplet.user_data).to include('ExecStop=/usr/bin/docker stop krates-server-haproxy')
      end
    end
  end
end
