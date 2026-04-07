# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Ledger Nodes API', type: :request do
  let(:org_id) { SecureRandom.uuid }
  let(:token) { AuthToken.encode(org_id: org_id, user_id: 'user-1') }
  let(:headers) { { 'Authorization' => "Bearer #{token}", 'Content-Type' => 'application/json' } }

  around do |example|
    original = ENV.fetch('AUTH_SECRET', nil)
    ENV['AUTH_SECRET'] = 'test-secret'
    example.run
    ENV['AUTH_SECRET'] = original
  end

  let(:question_attrs) do
    {
      kind: 'question',
      scope: 'code',
      body: 'What needs to be done?',
      title: 'Sample question',
      author: 'human',
      stable_ref: SecureRandom.hex(16),
      org_id: org_id,
      recorded_at: Time.current.iso8601,
      status: 'proposed'
    }
  end

  describe 'GET /api/nodes' do
    before { create(:ledger_node, org_id: org_id, scope: 'code', status: 'proposed') }

    it 'returns 200 with nodes' do
      get '/api/nodes', headers: headers
      expect(response).to have_http_status(:ok)
    end

    it 'returns an array' do
      get '/api/nodes', headers: headers
      expect(JSON.parse(response.body)).to be_an(Array)
    end

    context 'when filtering by scope' do
      before { create(:ledger_node, org_id: org_id, scope: 'intent', status: 'proposed') }

      it 'returns only matching nodes' do
        get '/api/nodes', params: { scope: 'code' }, headers: headers
        scopes = JSON.parse(response.body).map { |n| n['scope'] }
        expect(scopes).to all(eq('code'))
      end
    end

    context 'when filtering by status' do
      before { create(:ledger_node, org_id: org_id, scope: 'code', status: 'closed') }

      it 'returns only matching nodes' do
        get '/api/nodes', params: { status: 'proposed' }, headers: headers
        statuses = JSON.parse(response.body).map { |n| n['status'] }
        expect(statuses).to all(eq('proposed'))
      end
    end

    context 'when filtering by author' do
      before { create(:ledger_node, org_id: org_id, author: 'agent', scope: 'code', status: 'proposed') }

      it 'returns only matching nodes' do
        get '/api/nodes', params: { author: 'human' }, headers: headers
        authors = JSON.parse(response.body).map { |n| n['author'] }
        expect(authors).to all(eq('human'))
      end
    end

    context 'when filtering by parent_id' do
      let(:parent) { create(:ledger_node, org_id: org_id) }
      let(:child) { create(:ledger_node, org_id: org_id) }

      before { create(:ledger_node_edge, parent: parent, child: child, edge_type: 'contains') }

      it 'returns only children of the given parent' do
        get '/api/nodes', params: { parent_id: parent.id }, headers: headers
        ids = JSON.parse(response.body).map { |n| n['id'] }
        expect(ids).to include(child.id)
      end
    end

    context 'without auth' do
      it 'returns 401' do
        get '/api/nodes'
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'POST /api/nodes' do
    it 'creates a question node and returns 201' do
      post '/api/nodes', params: { node: question_attrs }.to_json, headers: headers
      expect(response).to have_http_status(:created)
    end

    it 'returns the created node' do
      post '/api/nodes', params: { node: question_attrs }.to_json, headers: headers
      expect(JSON.parse(response.body)['kind']).to eq('question')
    end

    context 'with invalid params' do
      it 'returns 422' do
        post '/api/nodes', params: { node: { kind: 'invalid' } }.to_json, headers: headers
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context 'without auth' do
      it 'returns 401' do
        post '/api/nodes', params: { node: question_attrs }.to_json,
             headers: { 'Content-Type' => 'application/json' }
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'GET /api/nodes/:id' do
    let(:node) { create(:ledger_node, org_id: org_id) }

    it 'returns 200 with the node' do
      get "/api/nodes/#{node.id}", headers: headers
      expect(response).to have_http_status(:ok)
    end

    it 'returns the correct node' do
      get "/api/nodes/#{node.id}", headers: headers
      expect(JSON.parse(response.body)['id']).to eq(node.id)
    end

    context 'when not found' do
      it 'returns 404' do
        get "/api/nodes/#{SecureRandom.uuid}", headers: headers
        expect(response).to have_http_status(:not_found)
      end
    end

    context 'without auth' do
      it 'returns 401' do
        get "/api/nodes/#{node.id}"
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'POST /api/nodes/:id/verdict' do
    let(:question) { create(:ledger_node, org_id: org_id, kind: 'question', status: 'proposed') }
    let(:answer) { create(:ledger_node, :answer, org_id: org_id) }

    before { create(:ledger_node_edge, parent: question, child: answer, edge_type: 'contains') }

    context 'with verdict true' do
      it 'closes the parent question' do
        post "/api/nodes/#{answer.id}/verdict",
             params: { verdict: true, accepted_by_id: 'user-1' }.to_json,
             headers: headers
        expect(response).to have_http_status(:ok)
        expect(question.reload.status).to eq('closed')
      end
    end

    context 'with verdict false' do
      before { question.update!(status: 'closed') }

      it 're-opens the parent question' do
        post "/api/nodes/#{answer.id}/verdict",
             params: { verdict: false, accepted_by_id: 'user-2' }.to_json,
             headers: headers
        expect(response).to have_http_status(:ok)
        expect(question.reload.status).to eq('proposed')
      end
    end

    context 'when called on a question node' do
      it 'returns 422' do
        post "/api/nodes/#{question.id}/verdict",
             params: { verdict: true }.to_json,
             headers: headers
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context 'without auth' do
      it 'returns 401' do
        post "/api/nodes/#{answer.id}/verdict", params: { verdict: true }.to_json,
             headers: { 'Content-Type' => 'application/json' }
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'POST /api/nodes/:id/comments' do
    let(:question) { create(:ledger_node, org_id: org_id, kind: 'question', status: 'proposed') }
    let(:answer) { create(:ledger_node, :answer, org_id: org_id) }

    it 'returns 200 for a question node' do
      post "/api/nodes/#{question.id}/comments", headers: headers
      expect(response).to have_http_status(:ok)
    end

    it 'returns 422 for an answer node' do
      post "/api/nodes/#{answer.id}/comments", headers: headers
      expect(response).to have_http_status(:unprocessable_entity)
    end

    context 'without auth' do
      it 'returns 401' do
        post "/api/nodes/#{question.id}/comments"
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
