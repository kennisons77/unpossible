# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Feature Flags API', type: :request do
  let(:org_id) { SecureRandom.uuid }
  let(:token) { AuthToken.encode(org_id: org_id, user_id: 'user-1') }
  let(:headers) { { 'Authorization' => "Bearer #{token}", 'Content-Type' => 'application/json' } }

  around do |example|
    original = ENV.fetch('AUTH_SECRET', nil)
    ENV['AUTH_SECRET'] = 'test-secret'
    example.run
    ENV['AUTH_SECRET'] = original
  end

  describe 'POST /api/feature_flags' do
    let(:valid_params) { { key: 'module.feature' } }

    it 'creates flag and returns 201' do
      post '/api/feature_flags', params: valid_params.to_json, headers: headers
      expect(response).to have_http_status(:created)
      expect(JSON.parse(response.body)['key']).to eq('module.feature')
    end

    it 'sets org_id from JWT token, not from params' do
      post '/api/feature_flags', params: { key: 'module.feature' }.to_json, headers: headers
      expect(JSON.parse(response.body)['org_id']).to eq(org_id)
    end

    it 'ignores org_id in params and uses token org_id' do
      other_org = SecureRandom.uuid
      post '/api/feature_flags', params: { key: 'module.feature', org_id: other_org }.to_json, headers: headers
      expect(response).to have_http_status(:created)
      expect(JSON.parse(response.body)['org_id']).to eq(org_id)
    end

    it 'returns 422 for duplicate key' do
      create(:analytics_feature_flag, key: 'module.feature', org_id: org_id)
      post '/api/feature_flags', params: valid_params.to_json, headers: headers
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'returns 201 without metadata.hypothesis' do
      post '/api/feature_flags', params: { key: 'module.no_hypothesis' }.to_json, headers: headers
      expect(response).to have_http_status(:created)
    end

    it 'returns 401 without auth' do
      post '/api/feature_flags', params: valid_params.to_json,
           headers: { 'Content-Type' => 'application/json' }
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'PATCH /api/feature_flags/:key' do
    let!(:flag) { create(:analytics_feature_flag, key: 'module.toggle', org_id: org_id, enabled: false) }

    it 'updates enabled and returns 200' do
      patch '/api/feature_flags/module.toggle', params: { enabled: true }.to_json, headers: headers
      expect(response).to have_http_status(:ok)
      expect(flag.reload.enabled).to be true
    end

    it 'returns 404 for unknown key' do
      patch '/api/feature_flags/module.missing', params: { enabled: true }.to_json, headers: headers
      expect(response).to have_http_status(:not_found)
    end

    it 'returns 401 without auth' do
      patch '/api/feature_flags/module.toggle', params: { enabled: true }.to_json,
            headers: { 'Content-Type' => 'application/json' }
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'GET /api/feature_flags' do
    let!(:active_flag)   { create(:analytics_feature_flag, org_id: org_id, status: 'active') }
    let!(:archived_flag) { create(:analytics_feature_flag, org_id: org_id, status: 'archived') }

    it 'returns active flags and excludes archived by default' do
      get '/api/feature_flags', headers: headers
      expect(response).to have_http_status(:ok)
      keys = JSON.parse(response.body).map { |f| f['key'] }
      expect(keys).to include(active_flag.key)
      expect(keys).not_to include(archived_flag.key)
    end

    it 'includes archived flags with ?status=archived' do
      get '/api/feature_flags?status=archived', headers: headers
      expect(response).to have_http_status(:ok)
      keys = JSON.parse(response.body).map { |f| f['key'] }
      expect(keys).to include(active_flag.key)
      expect(keys).to include(archived_flag.key)
    end

    it 'returns 401 without auth' do
      get '/api/feature_flags', headers: { 'Content-Type' => 'application/json' }
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
