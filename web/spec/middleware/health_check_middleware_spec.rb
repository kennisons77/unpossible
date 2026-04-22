# frozen_string_literal: true

require 'rails_helper'

RSpec.describe HealthCheckMiddleware, spec: "specifications/system/infrastructure/concept.md#health-check" do
  let(:app) { ->(env) { [200, {}, ['ok']] } }
  let(:middleware) { described_class.new(app) }

  def env_for(path, method: 'GET')
    Rack::MockRequest.env_for(path, method: method)
  end

  describe 'GET /health' do
    context 'when DB is reachable' do
      it 'returns 200 with empty body' do
        status, _headers, body = middleware.call(env_for('/health'))
        expect(status).to eq(200)
        expect(body.join).to eq('')
      end
    end

    context 'when DB is unreachable' do
      before do
        allow(ActiveRecord::Base.connection).to receive(:execute).and_raise(PG::ConnectionBad)
      end

      it 'returns 503 with empty body' do
        status, _headers, body = middleware.call(env_for('/health'))
        expect(status).to eq(503)
        expect(body.join).to eq('')
      end
    end

    it 'does not forward to the inner app' do
      expect(app).not_to receive(:call)
      middleware.call(env_for('/health'))
    end
  end

  describe 'non-health paths' do
    it 'forwards GET /up to the inner app' do
      status, _headers, body = middleware.call(env_for('/up'))
      expect(status).to eq(200)
      expect(body).to eq(['ok'])
    end

    it 'forwards POST /health to the inner app' do
      status, _headers, body = middleware.call(env_for('/health', method: 'POST'))
      expect(status).to eq(200)
      expect(body).to eq(['ok'])
    end
  end

  describe 'middleware position' do
    it 'is inserted before all other middleware' do
      stack = Rails.application.middleware.map(&:name)
      expect(stack.first).to eq('HealthCheckMiddleware')
    end
  end
end
