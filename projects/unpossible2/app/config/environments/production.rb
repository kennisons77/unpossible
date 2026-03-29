# frozen_string_literal: true

Rails.application.configure do
  config.cache_classes = true
  config.eager_load = true
  config.consider_all_requests_local = false
  config.action_controller.perform_caching = true

  config.public_file_server.enabled = ENV['RAILS_SERVE_STATIC_FILES'].present?

  config.log_level = :info
  config.log_tags = [:request_id]

  config.active_support.report_deprecations = false
  config.active_record.dump_schema_after_migration = false

  config.force_ssl = true
end
