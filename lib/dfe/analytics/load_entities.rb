# frozen_string_literal: true

module DfE
  module Analytics
    class LoadEntities
      # from https://cloud.google.com/bigquery/quotas#streaming_inserts
      BQ_BATCH_ROWS = 500

      def initialize(entity_name:)
        @entity_name = entity_name
      end

      def run
        model = DfE::Analytics.model_for_entity(@entity_name)

        unless model.any?
          Rails.logger.info("No entities to process for #{@entity_name}")
          return
        end

        unless model.primary_key.to_sym == :id
          Rails.logger.info("Not processing #{@entity_name} as we do not support non-id primary keys")
          return
        end

        Rails.logger.info("Processing data for #{@entity_name} with row count #{model.count}")

        batch_count = 0

        model.in_batches(of: BQ_BATCH_ROWS) do |relation|
          batch_count += 1
          ids = relation.pluck(:id)
          DfE::Analytics::LoadEntityBatch.perform_later(model.to_s, ids)
        end

        Rails.logger.info "Enqueued #{batch_count} batches of #{BQ_BATCH_ROWS} #{@entity_name} records for importing to BigQuery"
      end
    end
  end
end
