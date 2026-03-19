require_relative "boot"

require "rails"
require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"
require "active_storage/engine"
require "action_controller/railtie"
require "action_view/railtie"

Bundler.require(*Rails.groups)

module SovereignLibrary
  class Application < Rails::Application
    config.load_defaults 8.0

    config.active_job.queue_adapter = :solid_queue
    config.active_storage.service = Rails.env.test? ? :test : :local

    config.generators do |g|
      g.test_framework :rspec
      g.fixture_replacement :factory_bot, dir: "spec/factories"
    end
  end
end
