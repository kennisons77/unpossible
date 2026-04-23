# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Analytics Dashboard UI', type: :request,
                                         spec: 'specifications/system/analytics-dashboard-ui.md' do
  let(:org_id) { SecureRandom.uuid }
  let(:token) { AuthToken.encode(org_id: org_id, user_id: 'user-1') }
  let(:auth_header) { { 'Authorization' => "Bearer #{token}" } }

  around do |example|
    original = ENV.fetch('AUTH_SECRET', nil)
    ENV['AUTH_SECRET'] = 'test-secret'
    example.run
    ENV['AUTH_SECRET'] = original
  end

  describe 'GET /analytics' do
    it 'renders summary cards' do
      create(:analytics_llm_metric, org_id: org_id, cost_estimate_usd: 0.05)
      create(:analytics_llm_metric, org_id: org_id, cost_estimate_usd: 0.10)
      create(:agents_agent_run, org_id: org_id, mode: 'build', status: 'completed')
      create(:agents_agent_run, org_id: org_id, mode: 'build', status: 'failed')

      get '/analytics', headers: auth_header

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Analytics Dashboard')
      expect(response.body).to include('Total Cost This Week')
      expect(response.body).to include('Total Runs This Week')
      expect(response.body).to include('Failure Rate')
      expect(response.body).to include('$0.1500')
      expect(response.body).to include('data-testid="total-runs">2</div>')
      expect(response.body).to include('50.0%')
    end

    it 'renders cost by provider/model table' do
      create(:analytics_llm_metric, org_id: org_id, provider: 'anthropic', model: 'claude-3',
                                    input_tokens: 100, output_tokens: 50, cost_estimate_usd: 0.01)
      create(:analytics_llm_metric, org_id: org_id, provider: 'anthropic', model: 'claude-3',
                                    input_tokens: 200, output_tokens: 100, cost_estimate_usd: 0.02)
      create(:analytics_llm_metric, org_id: org_id, provider: 'openai', model: 'gpt-4',
                                    input_tokens: 300, output_tokens: 150, cost_estimate_usd: 0.05)

      get '/analytics', headers: auth_header

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Cost by Provider / Model')
      expect(response.body).to include('anthropic')
      expect(response.body).to include('claude-3')
      expect(response.body).to include('openai')
      expect(response.body).to include('gpt-4')
    end

    it 'renders recent runs (last 20)' do
      25.times do |i|
        create(:agents_agent_run, org_id: org_id, mode: 'build', status: 'completed',
                                  created_at: i.minutes.ago)
      end

      get '/analytics', headers: auth_header

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Recent Runs')
      expect(response.body.scan('class="status-completed"').size).to eq(20)
    end

    it 'scopes data by org_id' do
      other_org = SecureRandom.uuid
      create(:analytics_llm_metric, org_id: other_org, provider: 'secret-provider',
                                    cost_estimate_usd: 9.99)

      get '/analytics', headers: auth_header

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include('secret-provider')
      expect(response.body).not_to include('$9.9900')
    end

    it 'returns 401 without a token' do
      get '/analytics'

      expect(response).to have_http_status(:unauthorized)
    end

    it 'returns 401 with an invalid token' do
      get '/analytics', headers: { 'Authorization' => 'Bearer invalid' }

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'GET /analytics/llm' do
    it 'renders cost breakdown by provider and model' do
      create(:analytics_llm_metric, org_id: org_id, provider: 'anthropic', model: 'claude-3',
                                    input_tokens: 100, output_tokens: 50, cost_estimate_usd: 0.01)
      create(:analytics_llm_metric, org_id: org_id, provider: 'openai', model: 'gpt-4',
                                    input_tokens: 200, output_tokens: 100, cost_estimate_usd: 0.05)

      get '/analytics/llm', headers: auth_header

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('LLM Metrics')
      expect(response.body).to include('anthropic')
      expect(response.body).to include('claude-3')
      expect(response.body).to include('openai')
      expect(response.body).to include('gpt-4')
      expect(response.body).to include('$0.0500')
    end

    it 'filters by from date' do
      create(:analytics_llm_metric, org_id: org_id, provider: 'recent', model: 'x',
                                    cost_estimate_usd: 0.001)
      create(:analytics_llm_metric, org_id: org_id, provider: 'old', model: 'x',
                                    cost_estimate_usd: 0.99, created_at: 10.days.ago)

      get '/analytics/llm', params: { from: 2.days.ago.to_date.to_s }, headers: auth_header

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('recent')
      expect(response.body).not_to include('$0.9900')
    end

    it 'filters by to date' do
      create(:analytics_llm_metric, org_id: org_id, provider: 'today', model: 'x',
                                    cost_estimate_usd: 0.50)

      get '/analytics/llm', params: { to: 1.day.ago.to_date.to_s }, headers: auth_header

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include('$0.5000')
      expect(response.body).to include('No data')
    end

    it 'scopes data by org_id' do
      other_org = SecureRandom.uuid
      create(:analytics_llm_metric, org_id: other_org, provider: 'secret-provider',
                                    cost_estimate_usd: 9.99)

      get '/analytics/llm', headers: auth_header

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include('secret-provider')
    end

    it 'returns 401 without a token' do
      get '/analytics/llm'

      expect(response).to have_http_status(:unauthorized)
    end
  end
end
