# frozen_string_literal: true

require_relative 'boot'

require 'rails/all'

Bundler.require(*Rails.groups)

module Unpossible2
  class Application < Rails::Application
    config.load_defaults 8.0

    # Autoload app/modules/ so each subdirectory maps to a namespace (e.g. Knowledge::)
    config.autoload_paths << Rails.root.join('app/modules')

    # Collapse module subdirectories (models/, services/, jobs/, controllers/) so that
    # e.g. ledger/models/node.rb resolves to Ledger::Node, not Ledger::Models::Node.
    config.to_prepare do
      %w[models services jobs controllers].each do |subdir|
        Dir[Rails.root.join("app/modules/*/#{subdir}")].each do |path|
          Rails.autoloaders.main.collapse(path)
        end
      end
    end

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

    # Background jobs via Solid Queue (Postgres-backed, no Redis)
    config.active_job.queue_adapter = :solid_queue
  end
end
