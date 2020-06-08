require 'kontena/plugin/digital_ocean/master/terminate_command'

describe Kontena::Plugin::DigitalOcean::Master::TerminateCommand do

  let(:subject) do
    described_class.new(File.basename($0))
  end

  let(:destroyer) do
    spy(:destroyer)
  end

  describe '#run' do
    it 'requires name' do
      expect {
        subject.run([])
      }.to raise_error(Clamp::UsageError)

    end

    it 'passes options to provisioner' do
      expect(subject).to receive(:destroyer).and_return(destroyer)
      expect(destroyer).to receive(:run!).with('test-master')
      subject.run([
        '--force',
        '--token',
        'secretone',
        'test-master',
      ])
    end
  end
end
