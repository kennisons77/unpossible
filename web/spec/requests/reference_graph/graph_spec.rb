# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Reference Graph UI', type: :request do
  let(:org_id) { SecureRandom.uuid }
  let(:token) { AuthToken.encode(org_id: org_id, user_id: 'user-1') }
  let(:auth_headers) { { 'Authorization' => "Bearer #{token}" } }

  let(:sample_graph) do
    {
      'generated_at' => '2026-05-20T00:00:00Z',
      'nodes' => [
        { 'id' => 'beat:9.1', 'type' => 'beat', 'label' => 'Research spike', 'status' => 'done' },
        { 'id' => 'beat:9.2', 'type' => 'beat', 'label' => 'Implement graph UI', 'status' => 'in_progress' },
        { 'id' => 'beat:10.1', 'type' => 'beat', 'label' => 'Future work', 'status' => 'todo' },
        { 'id' => 'beat:10.2', 'type' => 'beat', 'label' => 'Blocked task', 'status' => 'blocked' },
        { 'id' => 'spec:specifications/system/reference-graph/concept.md',
          'type' => 'spec_section', 'label' => 'reference-graph',
          'path' => 'specifications/system/reference-graph/concept.md' }
      ],
      'edges' => [
        { 'from' => 'beat:9.2', 'to' => 'spec:specifications/system/reference-graph/concept.md', 'type' => 'refs' }
      ]
    }
  end

  around do |example|
    ENV['AUTH_SECRET'] = 'test-secret'
    example.run
    ENV.delete('AUTH_SECRET')
  end

  before do
    allow(ReferenceGraph::ParserService).to receive(:call).and_return(sample_graph)
  end

  describe 'GET /graph/current' do
    it 'returns 200' do
      get graph_current_path, headers: auth_headers
      expect(response).to have_http_status(:ok)
      expect(response.content_type).to include('text/html')
    end

    it 'shows the in-progress beat' do
      get graph_current_path, headers: auth_headers
      expect(response.body).to include('Implement graph UI')
      expect(response.body).to include('in_progress')
    end

    it 'shows ancestor chain via refs edges' do
      get graph_current_path, headers: auth_headers
      expect(response.body).to include('reference-graph')
    end

    it 'shows empty state when no in-progress beat' do
      allow(ReferenceGraph::ParserService).to receive(:call).and_return(
        'nodes' => [], 'edges' => [], 'generated_at' => nil
      )
      get graph_current_path, headers: auth_headers
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('No in-progress beat found')
    end

    it 'requires auth' do
      get graph_current_path
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'GET /graph/open' do
    it 'returns 200 with filterable plan items' do
      get graph_open_path, headers: auth_headers
      expect(response).to have_http_status(:ok)
      expect(response.content_type).to include('text/html')
    end

    it 'shows non-done beats' do
      get graph_open_path, headers: auth_headers
      expect(response.body).to include('Implement graph UI')
      expect(response.body).to include('Future work')
      expect(response.body).to include('Blocked task')
      expect(response.body).not_to include('Research spike')
    end

    it 'filters by status' do
      get graph_open_path(status: 'blocked'), headers: auth_headers
      expect(response.body).to include('Blocked task')
      expect(response.body).not_to include('Future work')
    end

    it 'requires auth' do
      get graph_open_path
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'GET /graph/condensed' do
    it 'returns 200 with collapsible tree' do
      get graph_condensed_path, headers: auth_headers
      expect(response).to have_http_status(:ok)
      expect(response.content_type).to include('text/html')
      expect(response.body).to include('<details')
    end

    it 'groups nodes by type' do
      get graph_condensed_path, headers: auth_headers
      expect(response.body).to include('beat')
      expect(response.body).to include('spec section')
    end

    it 'filters by search query' do
      get graph_condensed_path(q: 'graph UI'), headers: auth_headers
      expect(response.body).to include('Implement graph UI')
      expect(response.body).not_to include('Research spike')
    end

    it 'shows empty state when no nodes match' do
      get graph_condensed_path(q: 'zzznomatch'), headers: auth_headers
      expect(response.body).to include('No nodes found')
    end

    it 'requires auth' do
      get graph_condensed_path
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
