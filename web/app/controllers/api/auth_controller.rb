# frozen_string_literal: true

module Api
  class AuthController < ApplicationController
    # POST /api/auth/token
    # Phase 0: shared secret auth — client sends { secret: "..." }, receives JWT
    def create
      provided = params[:secret].to_s
      expected = ENV.fetch('AUTH_SECRET')

      if provided == expected
        token = AuthToken.encode(org_id: params[:org_id] || 'default', user_id: params[:user_id] || 'default')
        render json: { token: token }, status: :created
      else
        render json: { error: 'Invalid secret' }, status: :unauthorized
      end
    end
  end
end
