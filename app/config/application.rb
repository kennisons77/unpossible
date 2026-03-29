# frozen_string_literal: true

require_relative 'boot'

require 'rails/all'

Bundler.require(*Rails.groups)

module Unpossible2
  class Application < Rails::Application
    config.load_defaults 8.0

    # Autoload app/modules/** so each module's classes are available
    config.autoload_paths += Dir[Rails.root.join('app/modules/**/')]

    # Structured logging via lograge
    config.log_formatter = ::Logger::Formatter.new

    # Filter sensitive params from logs
    config.filter_parameters += %i[
      api_key token password secret authorization
      access_token refresh_token private_key credential
    ]

    # Time zone
    config.time_zone = 'UTC'

    # API + full-stack (views needed for UI)
    config.api_only = false
  end
end
