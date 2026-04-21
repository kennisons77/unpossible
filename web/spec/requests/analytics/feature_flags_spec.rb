# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Feature Flags API', type: :request do
  let(:org_id) { SecureRandom.uuid }
  let(:token) { AuthToken.encode(org_id: org_id, user_id: 'user-1') }
  let(:Authorization) { "Bearer #{token}" }

  around do |example|
    original = ENV.fetch('AUTH_SECRET', nil)
    ENV['AUTH_SECRET'] = 'test-secret'
    example.run
    ENV['AUTH_SECRET'] = original
  end

  path '/api/feature_flags' do
    get 'List feature flags' do
      tags 'Feature Flags'
      produces 'application/json'
      security [{ bearerAuth: [] }]
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :status, in: :query, type: :string, required: false,
                description: 'Filter by status (omit for active only, "archived" for all)'

      response '200', 'returns active flags by default' do
        before do
          create(:analytics_feature_flag, org_id: org_id, status: 'active')
          create(:analytics_feature_flag, org_id: org_id, status: 'archived')
          # different org — must not appear
          create(:analytics_feature_flag, status: 'active')
        end
        run_test! do
          body = JSON.parse(response.body)
          expect(body.size).to eq(1)
          expect(body.first['org_id']).to eq(org_id)
        end
      end

      response '200', 'includes archived flags when status=archived' do
        before do
          create(:analytics_feature_flag, org_id: org_id, status: 'active')
          create(:analytics_feature_flag, org_id: org_id, status: 'archived')
        end
        let(:status) { 'archived' }
        run_test! do
          body = JSON.parse(response.body)
          expect(body.size).to eq(2)
        end
      end

      response '401', 'missing or invalid token' do
        let(:Authorization) { nil }
        run_test!
      end
    end

    post 'Create a feature flag' do
      tags 'Feature Flags'
      consumes 'application/json'
      produces 'application/json'
      security [{ bearerAuth: [] }]
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          key: { type: :string }
        },
        required: ['key']
      }

      response '201', 'creates flag with org_id from token' do
        let(:body) { { key: 'module.new_feature' } }
        run_test! do
          parsed = JSON.parse(response.body)
          expect(parsed['key']).to eq('module.new_feature')
          expect(parsed['org_id']).to eq(org_id)
        end
      end

      response '201', 'ignores org_id in params and uses token org_id' do
        let(:other_org) { SecureRandom.uuid }
        let(:body) { { key: 'module.another_feature', org_id: other_org } }
        run_test! do
          parsed = JSON.parse(response.body)
          expect(parsed['org_id']).to eq(org_id)
          expect(parsed['org_id']).not_to eq(other_org)
        end
      end

      response '422', 'duplicate key returns unprocessable entity' do
        before { create(:analytics_feature_flag, key: 'module.existing', org_id: org_id) }
        let(:body) { { key: 'module.existing' } }
        run_test! do
          parsed = JSON.parse(response.body)
          expect(parsed['errors']).to be_present
        end
      end

      response '401', 'missing or invalid token' do
        let(:Authorization) { nil }
        let(:body) { { key: 'module.feature' } }
        run_test!
      end
    end
  end

  path '/api/feature_flags/{key}' do
    patch 'Update a feature flag' do
      tags 'Feature Flags'
      consumes 'application/json'
      produces 'application/json'
      security [{ bearerAuth: [] }]
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :key, in: :path, type: :string, required: true
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          enabled: { type: :boolean }
        }
      }

      response '200', 'updates enabled flag' do
        before { create(:analytics_feature_flag, key: 'module.toggle', org_id: org_id, enabled: false) }
        let(:key) { 'module.toggle' }
        let(:body) { { enabled: true } }
        run_test! do
          expect(Analytics::FeatureFlag.find_by(key: 'module.toggle', org_id: org_id).enabled).to be true
        end
      end

      response '404', 'unknown key returns not found' do
        let(:key) { 'module.missing' }
        let(:body) { { enabled: true } }
        run_test!
      end

      response '401', 'missing or invalid token' do
        let(:Authorization) { nil }
        let(:key) { 'module.toggle' }
        let(:body) { { enabled: true } }
        run_test!
      end
    end
  end
end
