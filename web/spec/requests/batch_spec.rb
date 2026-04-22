# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Batch API', type: :request, spec: "specifications/system/batch-requests.md#api" do
  let(:org_id) { SecureRandom.uuid }
  let(:token) { AuthToken.encode(org_id: org_id, user_id: 'user-1') }
  let(:Authorization) { "Bearer #{token}" }

  around do |example|
    original = ENV.fetch('AUTH_SECRET', nil)
    ENV['AUTH_SECRET'] = 'test-secret'
    example.run
    ENV['AUTH_SECRET'] = original
  end

  path '/api/batch' do
    post 'Fan out sub-requests' do
      tags 'Batch'
      consumes 'application/json'
      produces 'application/json'
      security [{ bearerAuth: [] }]
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          requests: {
            type: :array,
            items: {
              type: :object,
              properties: {
                method: { type: :string },
                url:    { type: :string },
                body:   { type: :object }
              },
              required: %w[method url]
            }
          }
        },
        required: ['requests']
      }

      response '200', 'returns aggregated responses' do
        # Use /up (no DB or auth required) so the sub-request succeeds
        let(:body) { { requests: [{ method: 'GET', url: '/up' }] } }
        run_test! do
          parsed = JSON.parse(response.body)
          expect(parsed['responses']).to be_an(Array)
          expect(parsed['responses'].size).to eq(1)
          expect(parsed['responses'][0]).to have_key('status')
        end
      end

      response '401', 'missing or invalid token returns unauthorized' do
        let(:Authorization) { nil }
        let(:body) { { requests: [{ method: 'GET', url: '/up' }] } }
        run_test! do
          parsed = JSON.parse(response.body)
          expect(parsed['error']).to eq('Unauthorized')
        end
      end

      response '422', 'malformed request body returns unprocessable entity' do
        # rswag serializes let(:body) as JSON, so truly malformed JSON cannot be sent via run_test!.
        # We test the equivalent: a valid JSON body that is not an object with a requests array.
        # Malformed JSON (parse error) is covered in spec/middleware/batch_request_middleware_spec.rb.
        let(:body) { [] }
        run_test! do
          expect(response.status).to eq(422)
          parsed = JSON.parse(response.body)
          expect(parsed['error']).to be_present
        end
      end

      response '422', 'exceeds max batch size returns unprocessable entity' do
        let(:body) do
          {
            requests: Array.new(BatchRequestMiddleware::MAX_BATCH_SIZE + 1) do
              { method: 'GET', url: '/up' }
            end
          }
        end
        run_test! do
          expect(response.status).to eq(422)
          parsed = JSON.parse(response.body)
          expect(parsed['error']).to match(/exceeds maximum/)
        end
      end
    end
  end
end
