# frozen_string_literal: true

# Test-only controller for verifying authenticate! behavior in request specs.
# Mounted at GET /test_auth only during specs that need it.
class TestAuthenticatedController < ApplicationController
  before_action :authenticate!

  def index
    render json: { org_id: current_org_id, user_id: current_user_id }, status: :ok
  end
end
