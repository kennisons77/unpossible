# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Agent Runs API', type: :request, spec: "specifications/system/agent-runner/concept.md#api" do
  let(:org_id) { SecureRandom.uuid }
  let(:token) { AuthToken.encode(org_id: org_id, user_id: 'user-1') }
  let(:Authorization) { "Bearer #{token}" }
  let(:sidecar_secret) { 'test-sidecar-token' }

  around do |example|
    original_auth = ENV.fetch('AUTH_SECRET', nil)
    original_sidecar = ENV.fetch('SIDECAR_TOKEN', nil)
    ENV['AUTH_SECRET'] = 'test-secret'
    ENV['SIDECAR_TOKEN'] = sidecar_secret
    example.run
    ENV['AUTH_SECRET'] = original_auth
    ENV['SIDECAR_TOKEN'] = original_sidecar
  end

  path '/api/agent_runs/start' do
    post 'Start an agent run' do
      tags 'Agent Runs'
      consumes 'application/json'
      produces 'application/json'
      security [{ bearerAuth: [] }]
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          run_id: { type: :string, format: :uuid },
          source_ref: { type: :string },
          mode: { type: :string },
          provider: { type: :string },
          model: { type: :string },
          prompt_sha256: { type: :string }
        },
        required: %w[run_id source_ref mode provider model]
      }

      response '201', 'run started' do
        let(:body) do
          {
            run_id: SecureRandom.uuid,
            source_ref: 'specifications/system/agent-runner/concept.md',
            mode: 'build',
            provider: 'claude',
            model: 'opus',
            prompt_sha256: SecureRandom.hex(32)
          }
        end
        run_test! do
          parsed = JSON.parse(response.body)
          expect(parsed['status']).to eq('running')
          expect(Agents::AgentRun.find(parsed['id']).org_id).to eq(org_id)
        end
      end

      response '200', 'dedup hit — cached run returned' do
        let(:sha) { SecureRandom.hex(32) }
        before { create(:agents_agent_run, prompt_sha256: sha, mode: 'build', status: 'completed') }
        let(:body) do
          {
            run_id: SecureRandom.uuid,
            source_ref: 'specifications/system/agent-runner/concept.md',
            mode: 'build',
            provider: 'claude',
            model: 'opus',
            prompt_sha256: sha
          }
        end
        run_test!
      end

      response '409', 'concurrent run already active for this source_ref' do
        before do
          create(:agents_agent_run,
                 source_ref: 'specifications/system/agent-runner/concept.md',
                 status: 'running')
        end
        let(:body) do
          {
            run_id: SecureRandom.uuid,
            source_ref: 'specifications/system/agent-runner/concept.md',
            mode: 'build',
            provider: 'claude',
            model: 'opus',
            prompt_sha256: SecureRandom.hex(32)
          }
        end
        run_test!
      end

      response '422', 'duplicate run_id' do
        let(:existing) { create(:agents_agent_run) }
        let(:body) do
          {
            run_id: existing.run_id,
            source_ref: 'specifications/system/agent-runner/concept.md',
            mode: 'build',
            provider: 'claude',
            model: 'opus',
            prompt_sha256: SecureRandom.hex(32)
          }
        end
        run_test!
      end

      response '401', 'missing or invalid token' do
        let(:Authorization) { nil }
        let(:body) do
          {
            run_id: SecureRandom.uuid,
            source_ref: 'specifications/system/agent-runner/concept.md',
            mode: 'build',
            provider: 'claude',
            model: 'opus'
          }
        end
        run_test!
      end
    end
  end

  path '/api/agent_runs/{id}/complete' do
    post 'Complete an agent run (sidecar only)' do
      tags 'Agent Runs'
      consumes 'application/json'
      produces 'application/json'
      parameter name: :id, in: :path, type: :integer, required: true
      parameter name: :'X-Sidecar-Token', in: :header, type: :string, required: true
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          input_tokens: { type: :integer },
          output_tokens: { type: :integer },
          cost_estimate_usd: { type: :number },
          duration_ms: { type: :integer }
        }
      }

      response '200', 'run completed' do
        let(:agent_run) { create(:agents_agent_run, status: 'running', org_id: org_id) }
        let(:id) { agent_run.id }
        let(:'X-Sidecar-Token') { sidecar_secret }
        let(:body) { { input_tokens: 100, output_tokens: 50, cost_estimate_usd: 0.001, duration_ms: 500 } }
        run_test! do
          expect(agent_run.reload.status).to eq('completed')
        end
      end

      response '401', 'missing or invalid sidecar token' do
        let(:agent_run) { create(:agents_agent_run, status: 'running', org_id: org_id) }
        let(:id) { agent_run.id }
        let(:'X-Sidecar-Token') { 'wrong' }
        let(:body) { { input_tokens: 100 } }
        run_test!
      end
    end
  end

  path '/api/agent_runs/{id}/input' do
    post 'Submit human input to a waiting run' do
      tags 'Agent Runs'
      consumes 'application/json'
      produces 'application/json'
      security [{ bearerAuth: [] }]
      parameter name: :id, in: :path, type: :integer, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          content: { type: :string }
        },
        required: ['content']
      }

      response '200', 'input recorded, run resumed' do
        let(:agent_run) { create(:agents_agent_run, status: 'waiting_for_input', org_id: org_id) }
        let(:id) { agent_run.id }
        let(:body) { { content: 'Here is my answer' } }
        run_test! do
          turn = Agents::AgentRunTurn.last
          expect(turn.kind).to eq('human_input')
          expect(turn.content).to eq('Here is my answer')
          expect(agent_run.reload.status).to eq('running')
        end
      end

      response '404', 'run not found or belongs to different org' do
        let(:other_run) { create(:agents_agent_run, status: 'waiting_for_input', org_id: SecureRandom.uuid) }
        let(:id) { other_run.id }
        let(:body) { { content: 'answer' } }
        run_test!
      end

      response '401', 'missing or invalid token' do
        let(:Authorization) { nil }
        let(:agent_run) { create(:agents_agent_run, status: 'waiting_for_input', org_id: org_id) }
        let(:id) { agent_run.id }
        let(:body) { { content: 'answer' } }
        run_test!
      end
    end
  end
end
