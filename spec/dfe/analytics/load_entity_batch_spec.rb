RSpec.describe DfE::Analytics::LoadEntityBatch do
  include ActiveJob::TestHelper

  with_model :Candidate do
    table do |t|
      t.string :email_address
    end
  end

  before do
    allow(DfE::Analytics::SendEvents).to receive(:perform_now)

    allow(DfE::Analytics).to receive(:allowlist).and_return({
      Candidate.table_name.to_sym => ['email_address']
    })
  end

  it 'splits a batch when the batch is too big' do
    perform_enqueued_jobs do
      c = Candidate.create(email_address: '12345678910')
      c2 = Candidate.create(email_address: '12345678910')
      stub_const('DfE::Analytics::LoadEntityBatch::BQ_BATCH_MAX_BYTES', 250)

      described_class.perform_now('Candidate', [c.id, c2.id])

      expect(DfE::Analytics::SendEvents).to have_received(:perform_now).twice
    end
  end

  it 'doesn’t split a batch unless it has to' do
    c = Candidate.create(email_address: '12345678910')
    c2 = Candidate.create(email_address: '12345678910')
    stub_const('DfE::Analytics::LoadEntityBatch::BQ_BATCH_MAX_BYTES', 500)

    described_class.perform_now('Candidate', [c.id, c2.id])

    expect(DfE::Analytics::SendEvents).to have_received(:perform_now).once
  end

  it 'accepts its first arg as a String to support Rails < 6.1' do
    # Rails 6.1rc1 added support for deserializing Class and Module params
    c = Candidate.create(email_address: 'foo@example.com')

    described_class.perform_now('Candidate', [c.id])

    expect(DfE::Analytics::SendEvents).to have_received(:perform_now).once
  end

  if Gem::Version.new(Rails.version) >= Gem::Version.new('6.1')
    it 'accepts its first arg as a Class' do
      # backwards compatability with existing enqueued jobs
      c = Candidate.create(email_address: 'foo@example.com')

      described_class.perform_now(Candidate, [c.id])

      expect(DfE::Analytics::SendEvents).to have_received(:perform_now).once
    end
  end
end
