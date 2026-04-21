# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Analytics Metrics API', type: :request do
  let(:org_id) { SecureRandom.uuid }
  let(:token) { AuthToken.encode(org_id: org_id, user_id: 'user-1') }
  let(:Authorization) { "Bearer #{token}" }

  around do |example|
    original = ENV.fetch('AUTH_SECRET', nil)
    ENV['AUTH_SECRET'] = 'test-secret'
    example.run
    ENV['AUTH_SECRET'] = original
  end

  path '/api/analytics/llm' do
    get 'LLM cost aggregated by provider and model' do
      tags 'Analytics'
      produces 'application/json'
      security [{ bearerAuth: [] }]
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :from, in: :query, type: :string, required: false,
                description: 'Start date (YYYY-MM-DD)'
      parameter name: :to, in: :query, type: :string, required: false,
                description: 'End date (YYYY-MM-DD)'

      response '200', 'cost aggregated by provider and model' do
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
        run_test! do
          body = JSON.parse(response.body)
          expect(body.size).to eq(2)
          claude = body.find { |r| r['provider'] == 'anthropic' }
          expect(claude['total_input_tokens']).to eq(300)
          expect(claude['total_output_tokens']).to eq(150)
          expect(claude['total_cost_usd']).to be_within(0.0001).of(0.003)
        end
      end

      response '200', 'filters by from date' do
        before do
          create(:analytics_llm_metric, org_id: org_id, provider: 'anthropic', model: 'claude-3',
                 cost_estimate_usd: 0.001, input_tokens: 100, output_tokens: 50)
          create(:analytics_llm_metric, org_id: org_id, provider: 'anthropic', model: 'claude-3',
                 cost_estimate_usd: 0.002, input_tokens: 200, output_tokens: 100)
          create(:analytics_llm_metric, org_id: org_id, provider: 'anthropic', model: 'claude-3',
                 cost_estimate_usd: 0.1, input_tokens: 50, output_tokens: 25,
                 created_at: 10.days.ago)
        end
        let(:from) { 2.days.ago.to_date.to_s }
        run_test! do
          body = JSON.parse(response.body)
          claude = body.find { |r| r['provider'] == 'anthropic' }
          expect(claude['total_cost_usd']).to be_within(0.0001).of(0.003)
        end
      end

      response '200', 'filters by to date — returns empty when all records are recent' do
        before do
          create(:analytics_llm_metric, org_id: org_id, provider: 'anthropic', model: 'claude-3',
                 cost_estimate_usd: 0.001)
        end
        let(:to) { 1.day.ago.to_date.to_s }
        run_test! do
          body = JSON.parse(response.body)
          expect(body).to be_empty
        end
      end

      response '401', 'missing or invalid token' do
        let(:Authorization) { nil }
        run_test!
      end
    end
  end

  path '/api/analytics/loops' do
    get 'Run counts and failure rates by mode' do
      tags 'Analytics'
      produces 'application/json'
      security [{ bearerAuth: [] }]
      parameter name: :Authorization, in: :header, type: :string, required: true

      response '200', 'run counts and failure rates by mode' do
        before do
          create(:agents_agent_run, org_id: org_id, mode: 'build', status: 'completed')
          create(:agents_agent_run, org_id: org_id, mode: 'build', status: 'failed')
          create(:agents_agent_run, org_id: org_id, mode: 'plan', status: 'completed')
          # different org — must not appear
          create(:agents_agent_run, mode: 'build', status: 'completed')
        end
        run_test! do
          body = JSON.parse(response.body)
          build_row = body.find { |r| r['mode'] == 'build' }
          expect(build_row['total_runs']).to eq(2)
          expect(build_row['failed_runs']).to eq(1)
          expect(build_row['failure_rate']).to eq(0.5)
          plan_row = body.find { |r| r['mode'] == 'plan' }
          expect(plan_row['total_runs']).to eq(1)
          expect(plan_row['failure_rate']).to eq(0.0)
        end
      end

      response '401', 'missing or invalid token' do
        let(:Authorization) { nil }
        run_test!
      end
    end
  end

  path '/api/analytics/summary' do
    get 'Weekly totals: cost, runs, error rate' do
      tags 'Analytics'
      produces 'application/json'
      security [{ bearerAuth: [] }]
      parameter name: :Authorization, in: :header, type: :string, required: true

      response '200', 'weekly totals' do
        before do
          create(:analytics_llm_metric, org_id: org_id, cost_estimate_usd: 0.01)
          create(:analytics_llm_metric, org_id: org_id, cost_estimate_usd: 0.02)
          create(:agents_agent_run, org_id: org_id, mode: 'build', status: 'completed')
          create(:agents_agent_run, org_id: org_id, mode: 'build', status: 'failed')
          # old record outside this week — must not count toward cost
          create(:analytics_llm_metric, org_id: org_id, cost_estimate_usd: 9.99, created_at: 2.weeks.ago)
        end
        run_test! do
          body = JSON.parse(response.body)
          expect(body['total_cost_usd']).to be_within(0.0001).of(0.03)
          expect(body['completed_runs']).to eq(1)
          expect(body['total_runs']).to eq(2)
          expect(body['loop_error_rate']).to eq(0.5)
          expect(body['week_start']).to be_present
        end
      end

      response '401', 'missing or invalid token' do
        let(:Authorization) { nil }
        run_test!
      end
    end
  end

  path '/api/analytics/events' do
    get 'Paginated analytics events' do
      tags 'Analytics'
      produces 'application/json'
      security [{ bearerAuth: [] }]
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :event_name, in: :query, type: :string, required: false
      parameter name: :from, in: :query, type: :string, required: false,
                description: 'ISO8601 timestamp'
      parameter name: :to, in: :query, type: :string, required: false,
                description: 'ISO8601 timestamp'
      parameter name: :page, in: :query, type: :integer, required: false
      parameter name: :per_page, in: :query, type: :integer, required: false

      response '200', 'paginated events for the org' do
        before do
          create(:analytics_event, org_id: org_id, event_name: 'task.promoted',
                 timestamp: 1.hour.ago, received_at: 1.hour.ago)
          create(:analytics_event, org_id: org_id, event_name: 'loop.iteration_completed',
                 timestamp: 2.hours.ago, received_at: 2.hours.ago)
          create(:analytics_event, org_id: org_id, event_name: 'task.promoted',
                 timestamp: 3.days.ago, received_at: 3.days.ago)
          # different org — must not appear
          create(:analytics_event, org_id: SecureRandom.uuid, event_name: 'task.promoted')
        end
        run_test! do
          body = JSON.parse(response.body)
          expect(body['total']).to eq(3)
          expect(body['events'].size).to eq(3)
          expect(body['page']).to eq(1)
        end
      end

      response '200', 'filters by event_name' do
        before do
          create(:analytics_event, org_id: org_id, event_name: 'task.promoted',
                 timestamp: 1.hour.ago, received_at: 1.hour.ago)
          create(:analytics_event, org_id: org_id, event_name: 'task.promoted',
                 timestamp: 3.days.ago, received_at: 3.days.ago)
          create(:analytics_event, org_id: org_id, event_name: 'loop.iteration_completed',
                 timestamp: 2.hours.ago, received_at: 2.hours.ago)
        end
        let(:event_name) { 'task.promoted' }
        run_test! do
          body = JSON.parse(response.body)
          expect(body['total']).to eq(2)
          expect(body['events'].all? { |e| e['event_name'] == 'task.promoted' }).to be true
        end
      end

      response '200', 'filters by from date' do
        before do
          create(:analytics_event, org_id: org_id, event_name: 'task.promoted',
                 timestamp: 1.hour.ago, received_at: 1.hour.ago)
          create(:analytics_event, org_id: org_id, event_name: 'loop.iteration_completed',
                 timestamp: 2.hours.ago, received_at: 2.hours.ago)
          create(:analytics_event, org_id: org_id, event_name: 'task.promoted',
                 timestamp: 3.days.ago, received_at: 3.days.ago)
        end
        let(:from) { 2.days.ago.iso8601 }
        run_test! do
          body = JSON.parse(response.body)
          expect(body['total']).to eq(2)
        end
      end

      response '200', 'filters by to date' do
        before do
          create(:analytics_event, org_id: org_id, event_name: 'task.promoted',
                 timestamp: 1.hour.ago, received_at: 1.hour.ago)
          create(:analytics_event, org_id: org_id, event_name: 'loop.iteration_completed',
                 timestamp: 2.hours.ago, received_at: 2.hours.ago)
          create(:analytics_event, org_id: org_id, event_name: 'task.promoted',
                 timestamp: 3.days.ago, received_at: 3.days.ago)
        end
        let(:to) { 2.days.ago.iso8601 }
        run_test! do
          body = JSON.parse(response.body)
          expect(body['total']).to eq(1)
        end
      end

      response '200', 'paginates results' do
        before do
          create(:analytics_event, org_id: org_id, event_name: 'task.promoted',
                 timestamp: 1.hour.ago, received_at: 1.hour.ago)
          create(:analytics_event, org_id: org_id, event_name: 'loop.iteration_completed',
                 timestamp: 2.hours.ago, received_at: 2.hours.ago)
          create(:analytics_event, org_id: org_id, event_name: 'task.promoted',
                 timestamp: 3.days.ago, received_at: 3.days.ago)
        end
        let(:per_page) { 2 }
        let(:page) { 1 }
        run_test! do
          body = JSON.parse(response.body)
          expect(body['events'].size).to eq(2)
          expect(body['per_page']).to eq(2)
        end
      end

      response '401', 'missing or invalid token' do
        let(:Authorization) { nil }
        run_test!
      end
    end
  end

  path '/api/analytics/flags/{key}' do
    get 'Feature flag exposure counts and conversion rates per variant' do
      tags 'Analytics'
      produces 'application/json'
      security [{ bearerAuth: [] }]
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :key, in: :path, type: :string, required: true

      let(:flag_key) { 'experiment.new_ui' }
      let(:key) { flag_key }
      let(:user_a) { SecureRandom.uuid }
      let(:user_b) { SecureRandom.uuid }
      let(:user_c) { SecureRandom.uuid }

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
               distinct_id: SecureRandom.uuid,
               properties: { flag_key: 'other.flag', variant: 'control', enabled: false })
      end

      response '200', 'exposure counts per variant' do
        run_test! do
          body = JSON.parse(response.body)
          expect(body['flag_key']).to eq(flag_key)
          control   = body['variants'].find { |v| v['variant'] == 'control' }
          treatment = body['variants'].find { |v| v['variant'] == 'treatment' }
          expect(control['exposure_count']).to eq(1)
          expect(treatment['exposure_count']).to eq(2)
        end
      end

      response '200', 'conversion rates per variant' do
        run_test! do
          body = JSON.parse(response.body)
          control   = body['variants'].find { |v| v['variant'] == 'control' }
          treatment = body['variants'].find { |v| v['variant'] == 'treatment' }
          expect(control['conversion_rate']).to eq(1.0)
          expect(treatment['conversion_rate']).to eq(0.5)
        end
      end

      response '401', 'missing or invalid token' do
        let(:Authorization) { nil }
        let(:key) { 'experiment.new_ui' }
        run_test!
      end
    end
  end
end
