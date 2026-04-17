# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Agent Runs API', type: :request do
  let(:org_id) { SecureRandom.uuid }
  let(:token) { AuthToken.encode(org_id: org_id, user_id: 'user-1') }
  let(:headers) { { 'Authorization' => "Bearer #{token}", 'Content-Type' => 'application/json' } }
  let(:sidecar_secret) { 'test-sidecar-token' }
  let(:sidecar_headers) { { 'X-Sidecar-Token' => sidecar_secret, 'Content-Type' => 'application/json' } }

  around do |example|
    original_auth = ENV.fetch('AUTH_SECRET', nil)
    original_sidecar = ENV.fetch('SIDECAR_TOKEN', nil)
    ENV['AUTH_SECRET'] = 'test-secret'
    ENV['SIDECAR_TOKEN'] = sidecar_secret
    example.run
    ENV['AUTH_SECRET'] = original_auth
    ENV['SIDECAR_TOKEN'] = original_sidecar
  end

  let(:valid_params) do
    {
      run_id: SecureRandom.uuid,
      source_ref: 'specs/system/agent-runner/spec.md',
      mode: 'build',
      provider: 'claude',
      model: 'opus',
      prompt_sha256: SecureRandom.hex(32)
    }
  end

  describe 'POST /api/agent_runs/start' do
    it 'creates AgentRun with status running and returns 201' do
      post '/api/agent_runs/start', params: valid_params.to_json, headers: headers
      expect(response).to have_http_status(:created)
      body = JSON.parse(response.body)
      expect(body['status']).to eq('running')
      expect(Agents::AgentRun.find(body['id']).org_id).to eq(org_id)
    end

    context 'with concurrent active run for same source_ref' do
      before { create(:agents_agent_run, source_ref: 'specs/system/agent-runner/spec.md', status: 'running') }

      it 'returns 409' do
        post '/api/agent_runs/start', params: valid_params.to_json, headers: headers
        expect(response).to have_http_status(:conflict)
      end
    end

    context 'with dedup hit' do
      let(:sha) { SecureRandom.hex(32) }

      before do
        create(:agents_agent_run, prompt_sha256: sha, mode: 'build', status: 'completed')
      end

      it 'returns cached run with 200' do
        post '/api/agent_runs/start',
             params: valid_params.merge(prompt_sha256: sha, mode: 'build').to_json,
             headers: headers
        expect(response).to have_http_status(:ok)
      end
    end

    context 'with duplicate run_id' do
      let(:existing) { create(:agents_agent_run) }

      it 'returns 422' do
        post '/api/agent_runs/start',
             params: valid_params.merge(run_id: existing.run_id).to_json,
             headers: headers
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context 'without auth' do
      it 'returns 401' do
        post '/api/agent_runs/start', params: valid_params.to_json,
             headers: { 'Content-Type' => 'application/json' }
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'POST /api/agent_runs/:id/complete' do
    let(:agent_run) { create(:agents_agent_run, status: 'running') }

    it 'updates record and returns 200' do
      post "/api/agent_runs/#{agent_run.id}/complete",
           params: { input_tokens: 100, output_tokens: 50, cost_estimate_usd: 0.001, duration_ms: 500 }.to_json,
           headers: sidecar_headers
      expect(response).to have_http_status(:ok)
      expect(agent_run.reload.status).to eq('completed')
    end

    context 'without sidecar token' do
      it 'returns 401' do
        post "/api/agent_runs/#{agent_run.id}/complete",
             params: { input_tokens: 100 }.to_json,
             headers: headers
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'POST /api/agent_runs/:id/input' do
    let(:agent_run) { create(:agents_agent_run, status: 'waiting_for_input') }

    it 'appends human_input turn and returns 200' do
      post "/api/agent_runs/#{agent_run.id}/input",
           params: { content: 'Here is my answer' }.to_json,
           headers: headers
      expect(response).to have_http_status(:ok)
      turn = Agents::AgentRunTurn.last
      expect(turn.kind).to eq('human_input')
      expect(turn.content).to eq('Here is my answer')
      expect(agent_run.reload.status).to eq('running')
    end

    context 'without auth' do
      it 'returns 401' do
        post "/api/agent_runs/#{agent_run.id}/input",
             params: { content: 'answer' }.to_json,
             headers: { 'Content-Type' => 'application/json' }
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
