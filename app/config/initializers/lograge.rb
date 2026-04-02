# frozen_string_literal: true

Rails.application.config.lograge.enabled = true
Rails.application.config.lograge.formatter = Lograge::Formatters::Json.new
Rails.application.config.lograge.custom_options = lambda do |event|
  {
    request_id: event.payload[:request_id],
    user_id: event.payload[:user_id]
  }.compact
end
