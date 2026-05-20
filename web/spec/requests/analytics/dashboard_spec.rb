# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Analytics Dashboard UI', type: :request do
  let(:org_id) { SecureRandom.uuid }
  let(:token) { AuthToken.encode(org_id: org_id, user_id: 'user-1') }
  let(:auth_headers) { { 'Authorization' => "Bearer #{token}" } }

  around do |example|
    ENV['AUTH_SECRET'] = 'test-secret'
    example.run
    ENV.delete('AUTH_SECRET')
  end

  describe 'GET /analytics' do
    it 'returns 200 with summary cards' do
      create(:analytics_llm_metric, org_id: org_id, cost_estimate_usd: 0.005)
      create(:agents_agent_run, org_id: org_id, status: 'completed')
      get analytics_path, headers: auth_headers
      expect(response).to have_http_status(:ok)
      expect(response.content_type).to include('text/html')
      expect(response.body).to include('Cost this week')
      expect(response.body).to include('Runs this week')
      expect(response.body).to include('Failure rate')
    end

    it 'shows cost by provider/model table' do
      create(:analytics_llm_metric, org_id: org_id, provider: 'anthropic', model: 'claude-3', cost_estimate_usd: 0.01)
      get analytics_path, headers: auth_headers
      expect(response.body).to include('anthropic')
      expect(response.body).to include('claude-3')
    end

    it 'shows recent runs' do
      create(:agents_agent_run, org_id: org_id, mode: 'build', status: 'completed')
      get analytics_path, headers: auth_headers
      expect(response.body).to include('build')
      expect(response.body).to include('completed')
    end

    it 'requires auth' do
      get analytics_path
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'GET /analytics/llm' do
    it 'returns 200 with cost breakdown' do
      create(:analytics_llm_metric, org_id: org_id, provider: 'openai', model: 'gpt-4', cost_estimate_usd: 0.02)
      get analytics_llm_path, headers: auth_headers
      expect(response).to have_http_status(:ok)
      expect(response.content_type).to include('text/html')
      expect(response.body).to include('openai')
      expect(response.body).to include('gpt-4')
    end

    it 'filters by date range' do
      create(:analytics_llm_metric, org_id: org_id, provider: 'anthropic', created_at: 10.days.ago)
      create(:analytics_llm_metric, org_id: org_id, provider: 'openai', created_at: 1.day.ago)
      get analytics_llm_path(from: 5.days.ago.to_date.to_s, to: Date.today.to_s), headers: auth_headers
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('openai')
      expect(response.body).not_to include('anthropic')
    end

    it 'requires auth' do
      get analytics_llm_path
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
