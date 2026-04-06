# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'POST /api/auth/token', type: :request do
  let(:secret) { 'test-secret' }

  around do |example|
    original = ENV.fetch('AUTH_SECRET', nil)
    ENV['AUTH_SECRET'] = secret
    example.run
    ENV['AUTH_SECRET'] = original
  end

  context 'with valid secret' do
    it 'returns 201 with a token' do
      post '/api/auth/token', params: { secret: secret }, as: :json
      expect(response).to have_http_status(:created)
    end

    it 'returns a decodable JWT' do
      post '/api/auth/token', params: { secret: secret }, as: :json
      token = JSON.parse(response.body)['token']
      payload = AuthToken.decode(token)
      expect(payload[:org_id]).to eq('default')
    end
  end

  context 'with invalid secret' do
    it 'returns 401' do
      post '/api/auth/token', params: { secret: 'wrong' }, as: :json
      expect(response).to have_http_status(:unauthorized)
    end
  end
end

RSpec.describe 'authenticate!', type: :request do
  let(:auth_secret) { 'test-secret' }
  let(:sidecar_secret) { 'sidecar-secret' }
  let(:valid_token) { AuthToken.encode(org_id: 'org-1', user_id: 'user-1') }

  around do |example|
    original_auth = ENV.fetch('AUTH_SECRET', nil)
    original_sidecar = ENV.fetch('SIDECAR_TOKEN', nil)
    ENV['AUTH_SECRET'] = auth_secret
    ENV['SIDECAR_TOKEN'] = sidecar_secret
    example.run
    ENV['AUTH_SECRET'] = original_auth
    ENV['SIDECAR_TOKEN'] = original_sidecar
  end

  before do
    Rails.application.routes.draw do
      get 'test_auth' => 'test_authenticated#index'
      get 'up' => 'rails/health#show', as: :rails_health_check
      namespace :api do
        post 'auth/token', to: 'auth#create'
      end
    end
  end

  after do
    Rails.application.reload_routes!
  end

  context 'with valid JWT' do
    it 'returns 200 with org_id' do
      get '/test_auth', headers: { 'Authorization' => "Bearer #{valid_token}" }
      expect(response).to have_http_status(:ok)
    end

    it 'returns the correct org_id' do
      get '/test_auth', headers: { 'Authorization' => "Bearer #{valid_token}" }
      expect(JSON.parse(response.body)['org_id']).to eq('org-1')
    end
  end

  context 'with expired JWT' do
    it 'returns 401' do
      expired = AuthToken.encode(org_id: 'org-1', user_id: 'user-1', exp: 1.hour.ago.to_i)
      get '/test_auth', headers: { 'Authorization' => "Bearer #{expired}" }
      expect(response).to have_http_status(:unauthorized)
    end
  end

  context 'with tampered JWT' do
    it 'returns 401' do
      get '/test_auth', headers: { 'Authorization' => "Bearer #{valid_token}garbage" }
      expect(response).to have_http_status(:unauthorized)
    end
  end

  context 'with no token' do
    it 'returns 401' do
      get '/test_auth'
      expect(response).to have_http_status(:unauthorized)
    end
  end

  context 'with valid sidecar token' do
    it 'returns 200' do
      get '/test_auth', headers: { 'X-Sidecar-Token' => sidecar_secret }
      expect(response).to have_http_status(:ok)
    end
  end

  context 'with wrong sidecar token' do
    it 'returns 401' do
      get '/test_auth', headers: { 'X-Sidecar-Token' => 'wrong' }
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
