# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'GET /health', type: :request, spec: "specifications/system/infrastructure/concept.md#health-check" do
  path '/health' do
    get 'Health check' do
      tags 'Health'

      response '200', 'database reachable' do
        run_test!
      end

      response '503', 'database unreachable' do
        before do
          allow(ActiveRecord::Base.connection).to receive(:execute).and_raise(PG::ConnectionBad)
        end
        run_test!
      end
    end
  end
end
