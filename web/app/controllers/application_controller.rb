# frozen_string_literal: true

class ApplicationController < ActionController::Base
  # CSRF protection for browser requests; API clients use JWT
  protect_from_forgery with: :null_session, if: -> { request.format.json? }

  private

  def authenticate!
    token = bearer_token || sidecar_token
    raise AuthToken::InvalidToken, 'Missing token' if token.nil?

    if token == sidecar_secret
      @current_org_id = nil
      @current_user_id = nil
      return
    end

    payload = AuthToken.decode(token)
    @current_org_id = payload[:org_id]
    @current_user_id = payload[:user_id]
  rescue AuthToken::ExpiredToken
    render json: { error: 'Token expired' }, status: :unauthorized
  rescue AuthToken::InvalidToken
    render json: { error: 'Unauthorized' }, status: :unauthorized
  end

  def current_org_id
    @current_org_id
  end

  def current_user_id
    @current_user_id
  end

  def bearer_token
    header = request.headers['Authorization']
    header&.start_with?('Bearer ') ? header.delete_prefix('Bearer ') : nil
  end

  def sidecar_token
    request.headers['X-Sidecar-Token']
  end

  def sidecar_secret
    ENV.fetch('SIDECAR_TOKEN', nil)
  end
end
