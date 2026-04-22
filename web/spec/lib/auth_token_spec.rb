# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AuthToken, spec: "specifications/system/auth/concept.md#auth-token" do
  let(:org_id) { 'org-123' }
  let(:user_id) { 'user-456' }

  around do |example|
    original = ENV.fetch('AUTH_SECRET', nil)
    ENV['AUTH_SECRET'] = 'test-secret'
    example.run
    ENV['AUTH_SECRET'] = original
  end

  describe '.encode / .decode round-trip' do
    it 'returns the original org_id' do
      token = described_class.encode(org_id: org_id, user_id: user_id)
      payload = described_class.decode(token)
      expect(payload[:org_id]).to eq(org_id)
    end

    it 'returns the original user_id' do
      token = described_class.encode(org_id: org_id, user_id: user_id)
      payload = described_class.decode(token)
      expect(payload[:user_id]).to eq(user_id)
    end
  end

  describe '.decode' do
    context 'with an expired token' do
      it 'raises ExpiredToken' do
        token = described_class.encode(org_id: org_id, user_id: user_id, exp: 1.hour.ago.to_i)
        expect { described_class.decode(token) }.to raise_error(AuthToken::ExpiredToken)
      end
    end

    context 'with a tampered token' do
      it 'raises InvalidToken' do
        token = described_class.encode(org_id: org_id, user_id: user_id)
        expect { described_class.decode("#{token}garbage") }.to raise_error(AuthToken::InvalidToken)
      end
    end

    context 'with a token signed by a different secret' do
      it 'raises InvalidToken' do
        other_token = JWT.encode({ org_id: org_id, user_id: user_id }, 'wrong-secret', 'HS256')
        expect { described_class.decode(other_token) }.to raise_error(AuthToken::InvalidToken)
      end
    end
  end
end
