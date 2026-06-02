# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Agent Runs HTML UI', type: :request do
  let(:org_id) { SecureRandom.uuid }
  let(:token) { AuthToken.encode(org_id: org_id, user_id: 'user-1') }
  let(:auth_headers) { { 'Authorization' => "Bearer #{token}" } }

  around do |example|
    ENV['AUTH_SECRET'] = 'test-secret'
    example.run
    ENV.delete('AUTH_SECRET')
  end

  describe 'GET /agent_runs' do
    it 'returns 200 with paginated list' do
      create_list(:agents_agent_run, 3, org_id: org_id)
      get agent_runs_path, headers: auth_headers
      expect(response).to have_http_status(:ok)
      expect(response.content_type).to include('text/html')
    end

    it 'filters by mode' do
      create(:agents_agent_run, org_id: org_id, mode: 'plan')
      create(:agents_agent_run, org_id: org_id, mode: 'build')
      get agent_runs_path(mode: 'plan'), headers: auth_headers
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('plan')
    end

    it 'filters by status' do
      create(:agents_agent_run, org_id: org_id, status: 'completed')
      create(:agents_agent_run, org_id: org_id, status: 'running')
      get agent_runs_path(status: 'completed'), headers: auth_headers
      expect(response).to have_http_status(:ok)
    end

    it 'requires auth' do
      get agent_runs_path
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'GET /agent_runs/:id' do
    let(:run) { create(:agents_agent_run, org_id: org_id, mode: 'build', status: 'completed') }

    it 'returns 200 with run metadata and turns' do
      create(:agents_agent_run_turn, agent_run: run, position: 1, kind: 'llm_response', content: '**hello**')
      get agent_run_path(run), headers: auth_headers
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(run.run_id)
      expect(response.body).to include('llm_response')
    end

    it 'shows source_ref when present' do
      run.update!(source_ref: 'specifications/system/agent-runner/concept.md')
      get agent_run_path(run), headers: auth_headers
      expect(response.body).to include('specifications/system/agent-runner/concept.md')
    end

    it 'returns 404 for unknown id' do
      get agent_run_path('00000000-0000-0000-0000-000000000000'), headers: auth_headers
      expect(response).to have_http_status(:not_found)
    end

    it 'requires auth' do
      get agent_run_path(run)
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
