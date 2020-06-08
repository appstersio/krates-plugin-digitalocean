require 'kontena/plugin/digital_ocean/master/create_command'

describe Kontena::Plugin::DigitalOcean::Master::CreateCommand do

  let(:subject) do
    described_class.new(File.basename($0))
  end

  let(:provisioner) do
    spy(:provisioner)
  end

  before do
    # Supress display_logo output triggered by 'master create' hook in krates/cli/lib/kontena/callbacks/master/deploy/01_show_logo_before_deploy.rb
    allow_any_instance_of(Kontena::Cli::Common).to receive(:display_logo).and_return(spy)
  end

  describe '#run' do
    it 'prompts user if options are missing' do
      expect(subject).to receive(:prompt).at_least(:once).and_return(spy)
      allow(subject).to receive(:provisioner).and_return(provisioner)
      allow(subject).to receive(:ask_ssh_key).and_return(1)
      subject.run(['--name', 'foo', '--skip-auth-provider'])
    end

    it 'passes options to provisioner' do
      options = [
        '--token', 'secretone',
        '--name', 'test-master',
        '--no-prompt',
        '--skip-auth-provider',
        '--region', 'sfo1',
        '--size', '2gb'
      ]
      expect(subject).to receive(:provisioner).with('secretone').and_return(provisioner)
      allow(subject).to receive(:ask_ssh_key).and_return(1)
      expect(provisioner).to receive(:run!).with(
        hash_including(
          ssh_key_id: 1, name: 'test-master'
        )
      )
      subject.run(options)
    end
  end
end
