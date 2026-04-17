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

  describe 'GET /api/analytics/events' do
    let(:other_org) { SecureRandom.uuid }

    before do
      create(:analytics_event, org_id: org_id, event_name: 'task.promoted',
             timestamp: 1.hour.ago, received_at: 1.hour.ago)
      create(:analytics_event, org_id: org_id, event_name: 'loop.iteration_completed',
             timestamp: 2.hours.ago, received_at: 2.hours.ago)
      create(:analytics_event, org_id: org_id, event_name: 'task.promoted',
             timestamp: 3.days.ago, received_at: 3.days.ago)
      # different org — must not appear
      create(:analytics_event, org_id: other_org, event_name: 'task.promoted')
    end

    it 'returns paginated events for the org' do
      get '/api/analytics/events', headers: headers
      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body['total']).to eq(3)
      expect(body['events'].size).to eq(3)
      expect(body['page']).to eq(1)
    end

    it 'filters by event_name' do
      get '/api/analytics/events', params: { event_name: 'task.promoted' }, headers: headers
      body = JSON.parse(response.body)
      expect(body['total']).to eq(2)
      expect(body['events'].all? { |e| e['event_name'] == 'task.promoted' }).to be true
    end

    it 'filters by from date' do
      get '/api/analytics/events', params: { from: 2.days.ago.iso8601 }, headers: headers
      body = JSON.parse(response.body)
      expect(body['total']).to eq(2)
    end

    it 'filters by to date' do
      get '/api/analytics/events', params: { to: 2.days.ago.iso8601 }, headers: headers
      body = JSON.parse(response.body)
      expect(body['total']).to eq(1)
    end

    it 'paginates results' do
      get '/api/analytics/events', params: { per_page: 2, page: 1 }, headers: headers
      body = JSON.parse(response.body)
      expect(body['events'].size).to eq(2)
      expect(body['per_page']).to eq(2)
    end

    it 'returns 401 without auth' do
      get '/api/analytics/events'
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'GET /api/analytics/flags/:key' do
    let(:flag_key) { 'experiment.new_ui' }
    let(:user_a)   { SecureRandom.uuid }
    let(:user_b)   { SecureRandom.uuid }
    let(:user_c)   { SecureRandom.uuid }

    before do
      # user_a exposed to variant "control", then converted
      create(:analytics_event, org_id: org_id, event_name: '$feature_flag_called',
             distinct_id: user_a, properties: { flag_key: flag_key, variant: 'control', enabled: true })
      create(:analytics_event, org_id: org_id, event_name: 'task.promoted',
             distinct_id: user_a)

      # user_b exposed to variant "treatment", no conversion
      create(:analytics_event, org_id: org_id, event_name: '$feature_flag_called',
             distinct_id: user_b, properties: { flag_key: flag_key, variant: 'treatment', enabled: true })

      # user_c exposed to variant "treatment", converted
      create(:analytics_event, org_id: org_id, event_name: '$feature_flag_called',
             distinct_id: user_c, properties: { flag_key: flag_key, variant: 'treatment', enabled: true })
      create(:analytics_event, org_id: org_id, event_name: 'task.promoted',
             distinct_id: user_c)

      # different flag — must not appear
      create(:analytics_event, org_id: org_id, event_name: '$feature_flag_called',
             distinct_id: SecureRandom.uuid, properties: { flag_key: 'other.flag', variant: 'control', enabled: false })
    end

    it 'returns exposure counts per variant' do
      get "/api/analytics/flags/#{flag_key}", headers: headers
      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body['flag_key']).to eq(flag_key)
      control   = body['variants'].find { |v| v['variant'] == 'control' }
      treatment = body['variants'].find { |v| v['variant'] == 'treatment' }
      expect(control['exposure_count']).to eq(1)
      expect(treatment['exposure_count']).to eq(2)
    end

    it 'returns conversion rates per variant' do
      get "/api/analytics/flags/#{flag_key}", headers: headers
      body = JSON.parse(response.body)
      control   = body['variants'].find { |v| v['variant'] == 'control' }
      treatment = body['variants'].find { |v| v['variant'] == 'treatment' }
      expect(control['conversion_rate']).to eq(1.0)
      expect(treatment['conversion_rate']).to eq(0.5)
    end

    it 'returns 401 without auth' do
      get "/api/analytics/flags/#{flag_key}"
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
