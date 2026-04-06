# frozen_string_literal: true

require 'jwt'

# Encodes and decodes JWT tokens for API authentication.
# Payload: { org_id:, user_id:, exp: }
# Phase 0: signed with AUTH_SECRET env var (HS256).
class AuthToken
  ALGORITHM = 'HS256'
  TTL = 24 * 3600 # 24 hours

  class ExpiredToken < StandardError; end
  class InvalidToken < StandardError; end

  def self.encode(org_id:, user_id:, exp: Time.now.to_i + TTL)
    payload = { org_id: org_id, user_id: user_id, exp: exp }
    JWT.encode(payload, secret, ALGORITHM)
  end

  def self.decode(token)
    payload, = JWT.decode(token, secret, true, algorithms: [ALGORITHM])
    payload.transform_keys(&:to_sym)
  rescue JWT::ExpiredSignature
    raise ExpiredToken, 'Token has expired'
  rescue JWT::DecodeError => e
    raise InvalidToken, e.message
  end

  def self.secret
    ENV.fetch('AUTH_SECRET')
  end
  private_class_method :secret
end
