RSpec.describe DfE::Analytics::Fields do
  context 'with dummy data' do
    with_model :Candidate do
      table do |t|
        t.string :email_address
        t.string :first_name
        t.string :last_name
      end
    end

    let(:existing_allowlist) { { Candidate.table_name.to_sym => ['email_address'] } }
    let(:existing_blocklist) { { Candidate.table_name.to_sym => ['id'] } }

    before do
      allow(DfE::Analytics).to receive(:allowlist).and_return(existing_allowlist)
      allow(DfE::Analytics).to receive(:blocklist).and_return(existing_blocklist)
    end

    describe '.allowlist' do
      it 'returns all the fields in the analytics.yml file' do
        expect(described_class.allowlist).to eq(existing_allowlist)
      end
    end

    describe '.blocklist' do
      it 'returns all the fields in the analytics_blocklist.yml file' do
        expect(described_class.blocklist).to eq(existing_blocklist)
      end
    end

    describe '.unlisted_fields' do
      it 'returns all the fields in the model that aren’t in either list' do
        fields = described_class.unlisted_fields[Candidate.table_name.to_sym]
        expect(fields).to include('first_name')
        expect(fields).to include('last_name')
        expect(fields).not_to include('email_address')
        expect(fields).not_to include('id')
      end

      describe '.check!' do
        it 'raises an error' do
          expect { DfE::Analytics::Fields.check! }.to raise_error(DfE::Analytics::ConfigurationError, /New database field detected/)
        end
      end
    end

    describe '.conflicting_fields' do
      context 'when fields conflict' do
        let(:existing_allowlist) { { Candidate.table_name.to_sym => %w[email_address id first_name] } }
        let(:existing_blocklist) { { Candidate.table_name.to_sym => %w[email_address first_name] } }

        it 'returns the conflicting fields' do
          conflicts = described_class.conflicting_fields
          expect(conflicts[Candidate.table_name.to_sym]).to eq(%w[email_address first_name])
        end

        describe '.check!' do
          it 'raises an error' do
            expect { DfE::Analytics::Fields.check! }.to raise_error(DfE::Analytics::ConfigurationError, /Conflict detected/)
          end
        end
      end

      context 'when there are no conflicts' do
        let(:existing_allowlist) { { Candidate.table_name.to_sym => %w[email_address] } }
        let(:existing_blocklist) { { Candidate.table_name.to_sym => %w[id] } }

        it 'returns nothing' do
          conflicts = described_class.conflicting_fields
          expect(conflicts).to be_empty
        end
      end
    end

    describe '.generate_blocklist' do
      it 'returns all the fields in the model that aren’t in the allowlist' do
        fields = described_class.generate_blocklist[Candidate.table_name.to_sym]
        expect(fields).to include('first_name')
        expect(fields).to include('last_name')
        expect(fields).to include('id')
        expect(fields).not_to include('email_address')
      end
    end

    describe '.surplus_fields' do
      it 'returns nothing' do
        fields = described_class.surplus_fields[Candidate.table_name.to_sym]
        expect(fields).to be_nil
      end
    end

    context 'when the lists deal with an attribute that is no longer in the database' do
      let(:existing_allowlist) { { Candidate.table_name.to_sym => ['some_removed_field'] } }

      describe '.surplus_fields' do
        it 'returns the field that has been removed' do
          fields = described_class.surplus_fields[Candidate.table_name.to_sym]
          expect(fields).to eq ['some_removed_field']
        end
      end

      describe '.check!' do
        it 'raises an error' do
          expect { DfE::Analytics::Fields.check! }.to raise_error(DfE::Analytics::ConfigurationError, /Database field removed/)
        end
      end
    end
  end
end
