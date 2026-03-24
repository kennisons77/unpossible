# frozen_string_literal: true

class PipelineOrchestratorJob < ApplicationJob
  queue_as :default

  PIPELINE_STAGES = {
    categorized: :CategorizationService,
    identified: :IdentificationService,
    normalized: :NormalizationService,
    stored: :StorageService,
    enriched: :EnrichmentService
  }.freeze

  def perform(document_id)
    document = Document.find(document_id)

    PIPELINE_STAGES.each do |stage_name, service_class_name|
      service_class = service_class_name.to_s.constantize
      result = service_class.new(document).call

      unless result[:success]
        document.update!(
          review_required: true,
          review_reason: "#{stage_name} failed: #{result[:error]}"
        )
        return
      end

      document.update!(stage: stage_name)
    end
  end
end
