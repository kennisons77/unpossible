# frozen_string_literal: true

require "rails_helper"

RSpec.describe PipelineOrchestratorJob do
  let(:user) { User.create!(email_address: "test@example.com", password: "password123") }
  let(:document) { Document.create!(owner: user, stage: :acquired) }

  describe "#perform" do
    context "when all stages succeed" do
      before do
        PipelineOrchestratorJob::PIPELINE_STAGES.each_value do |service_class_name|
          service_class = service_class_name.to_s.constantize
          allow_any_instance_of(service_class).to receive(:call).and_return({ success: true })
        end
      end

      it "runs all stages in order" do
        PipelineOrchestratorJob::PIPELINE_STAGES.each_value do |service_class_name|
          service_class = service_class_name.to_s.constantize
          expect_any_instance_of(service_class).to receive(:call).and_return({ success: true })
        end

        described_class.new.perform(document.id)
      end

      it "updates stage after each success" do
        described_class.new.perform(document.id)
        document.reload
        expect(document.stage).to eq("enriched")
      end

      it "does not set review_required" do
        described_class.new.perform(document.id)
        document.reload
        expect(document.review_required).to be(false)
      end
    end

    context "when a stage fails" do
      before do
        allow_any_instance_of(CategorizationService).to receive(:call)
          .and_return({ success: false, error: "LLM timeout" })
      end

      it "stops at the failing stage" do
        expect_any_instance_of(IdentificationService).not_to receive(:call)

        described_class.new.perform(document.id)
      end

      it "sets review_required to true" do
        described_class.new.perform(document.id)
        document.reload
        expect(document.review_required).to be(true)
      end

      it "sets review_reason with stage and error" do
        described_class.new.perform(document.id)
        document.reload
        expect(document.review_reason).to eq("categorized failed: LLM timeout")
      end

      it "does not advance stage past failure" do
        described_class.new.perform(document.id)
        document.reload
        expect(document.stage).to eq("acquired")
      end
    end
  end
end
