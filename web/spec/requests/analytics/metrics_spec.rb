# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Analytics Metrics API', type: :request do
  let(:org_id) { SecureRandom.uuid }
  let(:token) { AuthToken.encode(org_id: org_id, user_id: 'user-1') }
  let(:headers) { { 'Authorization' => "Bearer #{token}" } }

  around do |example|
    original = ENV.fetch('AUTH_SECRET', nil)
    ENV['AUTH_SECRET'] = 'test-secret'
    example.run
    ENV['AUTH_SECRET'] = original
  end

  describe 'GET /api/analytics/llm' do
    before do
      create(:analytics_llm_metric, org_id: org_id, provider: 'anthropic', model: 'claude-3',
             input_tokens: 100, output_tokens: 50, cost_estimate_usd: 0.001)
      create(:analytics_llm_metric, org_id: org_id, provider: 'anthropic', model: 'claude-3',
             input_tokens: 200, output_tokens: 100, cost_estimate_usd: 0.002)
      create(:analytics_llm_metric, org_id: org_id, provider: 'openai', model: 'gpt-4',
             input_tokens: 300, output_tokens: 150, cost_estimate_usd: 0.005)
      # different org — must not appear
      create(:analytics_llm_metric, provider: 'anthropic', model: 'claude-3', cost_estimate_usd: 0.999)
    end

    it 'returns cost aggregated by provider and model' do
      get '/api/analytics/llm', headers: headers
      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body.size).to eq(2)
      claude = body.find { |r| r['provider'] == 'anthropic' }
      expect(claude['total_input_tokens']).to eq(300)
      expect(claude['total_output_tokens']).to eq(150)
      expect(claude['total_cost_usd']).to be_within(0.0001).of(0.003)
    end

    it 'filters by from date' do
      create(:analytics_llm_metric, org_id: org_id, provider: 'anthropic', model: 'claude-3',
             cost_estimate_usd: 0.1, created_at: 10.days.ago)
      get '/api/analytics/llm', params: { from: 2.days.ago.to_date.to_s }, headers: headers
      body = JSON.parse(response.body)
      claude = body.find { |r| r['provider'] == 'anthropic' }
      # only the 2 recent records, not the 10-days-ago one
      expect(claude['total_cost_usd']).to be_within(0.0001).of(0.003)
    end

    it 'filters by to date' do
      get '/api/analytics/llm', params: { to: 1.day.ago.to_date.to_s }, headers: headers
      body = JSON.parse(response.body)
      expect(body).to be_empty
    end

    it 'returns 401 without auth' do
      get '/api/analytics/llm'
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'GET /api/analytics/loops' do
    before do
      create(:agents_agent_run, org_id: org_id, mode: 'build', status: 'completed')
      create(:agents_agent_run, org_id: org_id, mode: 'build', status: 'failed')
      create(:agents_agent_run, org_id: org_id, mode: 'plan', status: 'completed')
      # different org — must not appear
      create(:agents_agent_run, mode: 'build', status: 'completed')
    end

    it 'returns run counts and failure rates by mode' do
      get '/api/analytics/loops', headers: headers
      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      build_row = body.find { |r| r['mode'] == 'build' }
      expect(build_row['total_runs']).to eq(2)
      expect(build_row['failed_runs']).to eq(1)
      expect(build_row['failure_rate']).to eq(0.5)
      plan_row = body.find { |r| r['mode'] == 'plan' }
      expect(plan_row['total_runs']).to eq(1)
      expect(plan_row['failure_rate']).to eq(0.0)
    end

    it 'returns 401 without auth' do
      get '/api/analytics/loops'
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'GET /api/analytics/summary' do
    before do
      create(:analytics_llm_metric, org_id: org_id, cost_estimate_usd: 0.01)
      create(:analytics_llm_metric, org_id: org_id, cost_estimate_usd: 0.02)
      create(:agents_agent_run, org_id: org_id, mode: 'build', status: 'completed')
      create(:agents_agent_run, org_id: org_id, mode: 'build', status: 'failed')
      # old record outside this week — must not count toward cost
      create(:analytics_llm_metric, org_id: org_id, cost_estimate_usd: 9.99, created_at: 2.weeks.ago)
    end

    it 'returns weekly totals' do
      get '/api/analytics/summary', headers: headers
      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body['total_cost_usd']).to be_within(0.0001).of(0.03)
      expect(body['completed_runs']).to eq(1)
      expect(body['total_runs']).to eq(2)
      expect(body['loop_error_rate']).to eq(0.5)
      expect(body['week_start']).to be_present
    end

    it 'returns 401 without auth' do
      get '/api/analytics/summary'
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
