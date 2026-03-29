# frozen_string_literal: true

class ApplicationController < ActionController::Base
  # CSRF protection for browser requests; API clients use JWT
  protect_from_forgery with: :null_session, if: -> { request.format.json? }
end
