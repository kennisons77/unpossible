# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Ledger UI', type: :request do
  let(:org_id) { SecureRandom.uuid }
  let(:token) { AuthToken.encode(org_id: org_id, user_id: 'user-1') }
  let(:headers) { { 'Authorization' => "Bearer #{token}" } }
  let(:project) { create(:ledger_project, org_id: org_id, name: 'test-project') }

  around do |example|
    original = ENV.fetch('AUTH_SECRET', nil)
    ENV['AUTH_SECRET'] = 'test-secret'
    example.run
    ENV['AUTH_SECRET'] = original
  end

  def create_question(attrs = {})
    create(:ledger_node, { kind: 'question', status: 'proposed', org_id: org_id }.merge(attrs))
  end

  describe 'GET /ledger' do
    context 'with valid auth' do
      it 'returns 200' do
        get '/ledger', headers: headers
        expect(response).to have_http_status(:ok)
      end

      it 'returns 200 when an in_progress node exists' do
        create_question(status: 'in_progress')
        get '/ledger', headers: headers
        expect(response).to have_http_status(:ok)
      end
    end

    context 'without auth' do
      it 'redirects' do
        get '/ledger'
        expect(response).to have_http_status(:redirect)
      end
    end
  end

  describe 'GET /ledger/open' do
    context 'with valid auth' do
      it 'returns 200' do
        create_question(status: 'proposed')
        get '/ledger/open', headers: headers
        expect(response).to have_http_status(:ok)
      end

      it 'excludes closed nodes' do
        create_question(status: 'closed')
        get '/ledger/open', headers: headers
        expect(response.body).not_to include('closed')
      end

      it 'filters by scope when param provided' do
        create_question(scope: 'intent', status: 'proposed')
        create_question(scope: 'code', status: 'proposed')
        get '/ledger/open', params: { scope: 'intent' }, headers: headers
        expect(response).to have_http_status(:ok)
      end
    end

    context 'without auth' do
      it 'redirects' do
        get '/ledger/open'
        expect(response).to have_http_status(:redirect)
      end
    end
  end

  describe 'GET /ledger/tree' do
    context 'with valid auth' do
      it 'returns 200' do
        get '/ledger/tree', headers: headers
        expect(response).to have_http_status(:ok)
      end

      it 'lists projects' do
        create_question(project: project)
        get '/ledger/tree', headers: headers
        expect(response.body).to include('test-project')
      end

      it 'filters results when q param provided' do
        create_question(title: 'unique-search-term', status: 'proposed', project: project)
        create_question(title: 'other node', status: 'proposed', project: project)
        get '/ledger/tree', params: { project: 'test-project', q: 'unique-search-term' }, headers: headers
        expect(response).to have_http_status(:ok)
        expect(response.body).to include('unique-search-term')
      end
    end

    context 'without auth' do
      it 'redirects' do
        get '/ledger/tree'
        expect(response).to have_http_status(:redirect)
      end
    end
  end

  describe 'GET /ledger/nodes/:id' do
    context 'with valid auth' do
      it 'returns 200 with the node' do
        node = create_question
        get "/ledger/nodes/#{node.id}", headers: headers
        expect(response).to have_http_status(:ok)
      end

      it 'renders the audit trail' do
        node = create_question
        create(:ledger_node_audit_event, node: node, from_status: 'proposed', to_status: 'in_progress')
        get "/ledger/nodes/#{node.id}", headers: headers
        expect(response).to have_http_status(:ok)
        expect(response.body).to include('in_progress')
      end
    end

    context 'without auth' do
      it 'redirects' do
        node = create_question
        get "/ledger/nodes/#{node.id}"
        expect(response).to have_http_status(:redirect)
      end
    end
  end
end
