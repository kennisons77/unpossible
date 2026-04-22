# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BatchRequestMiddleware do
  let(:inner_app) do
    lambda do |env|
      path = env['PATH_INFO']
      case path
      when '/api/ok'
        [200, { 'Content-Type' => 'application/json' }, ['{"result":"ok"}']]
      when '/api/fail'
        [500, { 'Content-Type' => 'application/json' }, ['{"error":"boom"}']]
      when '/api/not_found'
        [404, { 'Content-Type' => 'application/json' }, ['{"error":"not found"}']]
      when '/api/echo'
        body = env['rack.input'].read
        [200, { 'Content-Type' => 'application/json' }, [body]]
      else
        [404, {}, ['']]
      end
    end
  end

  let(:middleware) { described_class.new(inner_app) }

  def env_for(path, method: 'POST', body: nil, headers: {})
    opts = { method: method }
    opts[:input] = StringIO.new(body || '') if body
    env = Rack::MockRequest.env_for(path, **opts)
    headers.each { |k, v| env[k] = v }
    env
  end

  def batch_env(requests, headers: {})
    body = { requests: requests }.to_json
    env_for(
      '/api/batch',
      method: 'POST',
      body: body,
      headers: { 'CONTENT_TYPE' => 'application/json', 'HTTP_AUTHORIZATION' => 'Bearer token' }.merge(headers)
    )
  end

  describe 'non-batch paths' do
    it 'forwards other requests to the inner app' do
      status, _headers, body = middleware.call(env_for('/api/ok', method: 'GET'))
      expect(status).to eq(200)
      expect(body.join).to eq('{"result":"ok"}')
    end
  end

  describe 'POST /api/batch' do
    context 'without auth header' do
      it 'returns 401' do
        env = env_for('/api/batch', method: 'POST',
                      body: { requests: [] }.to_json,
                      headers: { 'CONTENT_TYPE' => 'application/json' })
        status, _headers, body = middleware.call(env)
        expect(status).to eq(401)
        parsed = JSON.parse(body.join)
        expect(parsed['error']).to eq('Unauthorized')
      end
    end

    it 'fans out sub-requests and returns aggregated responses' do
      env = batch_env([
        { 'method' => 'GET', 'url' => '/api/ok' },
        { 'method' => 'GET', 'url' => '/api/not_found' }
      ])
      status, _headers, body = middleware.call(env)
      expect(status).to eq(200)
      parsed = JSON.parse(body.join)
      expect(parsed['responses'].size).to eq(2)
      expect(parsed['responses'][0]['status']).to eq(200)
      expect(parsed['responses'][1]['status']).to eq(404)
    end

    it 'preserves response ordering' do
      env = batch_env([
        { 'method' => 'GET', 'url' => '/api/not_found' },
        { 'method' => 'GET', 'url' => '/api/ok' }
      ])
      _status, _headers, body = middleware.call(env)
      parsed = JSON.parse(body.join)
      expect(parsed['responses'][0]['status']).to eq(404)
      expect(parsed['responses'][1]['status']).to eq(200)
    end

    it 'does not fail the batch when an individual sub-request fails' do
      env = batch_env([
        { 'method' => 'GET', 'url' => '/api/ok' },
        { 'method' => 'GET', 'url' => '/api/fail' }
      ])
      status, _headers, body = middleware.call(env)
      expect(status).to eq(200)
      parsed = JSON.parse(body.join)
      expect(parsed['responses'][0]['status']).to eq(200)
      expect(parsed['responses'][1]['status']).to eq(500)
    end

    it 'returns 422 when batch size exceeds maximum' do
      requests = Array.new(BatchRequestMiddleware::MAX_BATCH_SIZE + 1) do
        { 'method' => 'GET', 'url' => '/api/ok' }
      end
      env = batch_env(requests)
      status, _headers, body = middleware.call(env)
      expect(status).to eq(422)
      parsed = JSON.parse(body.join)
      expect(parsed['error']).to match(/exceeds maximum/)
    end

    it 'returns 422 for malformed JSON' do
      env = env_for('/api/batch', method: 'POST', body: 'not json',
                    headers: { 'CONTENT_TYPE' => 'application/json', 'HTTP_AUTHORIZATION' => 'Bearer token' })
      status, _headers, body = middleware.call(env)
      expect(status).to eq(422)
      parsed = JSON.parse(body.join)
      expect(parsed['error']).to eq('Malformed JSON')
    end

    it 'returns 422 when requests is not an array' do
      env = env_for('/api/batch', method: 'POST',
                    body: { requests: 'not-an-array' }.to_json,
                    headers: { 'CONTENT_TYPE' => 'application/json', 'HTTP_AUTHORIZATION' => 'Bearer token' })
      status, _headers, body = middleware.call(env)
      expect(status).to eq(422)
    end

    it 'inherits auth headers from the outer request' do
      auth_app = lambda do |env|
        token = env['HTTP_AUTHORIZATION']
        if token == 'Bearer valid'
          [200, { 'Content-Type' => 'application/json' }, ['{"authed":true}']]
        else
          [401, { 'Content-Type' => 'application/json' }, ['{"error":"unauthorized"}']]
        end
      end
      mw = described_class.new(auth_app)

      env = batch_env(
        [{ 'method' => 'GET', 'url' => '/api/ok' }],
        headers: { 'HTTP_AUTHORIZATION' => 'Bearer valid' }
      )
      _status, _headers, body = mw.call(env)
      parsed = JSON.parse(body.join)
      expect(parsed['responses'][0]['status']).to eq(200)
      expect(parsed['responses'][0]['body']['authed']).to be true
    end

    it 'runs each sub-request through the full Rack stack' do
      call_count = 0
      counting_app = lambda do |env|
        call_count += 1
        [200, { 'Content-Type' => 'application/json' }, ['{"ok":true}']]
      end
      mw = described_class.new(counting_app)

      env = batch_env([
        { 'method' => 'GET', 'url' => '/api/a' },
        { 'method' => 'GET', 'url' => '/api/b' }
      ])
      mw.call(env)
      expect(call_count).to eq(2)
    end
  end
end
