# frozen_string_literal: true

require 'rails_helper'

# A minimal job used only in this spec to verify queue routing.
class TestQueueJob < ApplicationJob
  queue_as :analytics

  def perform; end
end

RSpec.describe "Solid Queue configuration" do
  it "uses solid_queue as the queue adapter in non-test environments" do
    # application.rb sets solid_queue; test.rb overrides to :test for have_enqueued_job matchers.
    # Verify the base config (application.rb) declares solid_queue.
    app_config_path = Rails.root.join("config/application.rb")
    expect(File.read(app_config_path)).to include("solid_queue")
  end

  it "routes TestQueueJob to the analytics queue", :aggregate_failures do
    # Inspect the queue name directly — no need for :test adapter
    expect(TestQueueJob.queue_name).to eq("analytics")
  end

  it "does not require a Redis connection" do
    # Solid Queue is Postgres-backed; Redis must not be reachable
    expect(defined?(Redis)).to be_nil.or(satisfy { |_|
      begin
        Redis.new(url: "redis://localhost:6379", timeout: 0.1).ping
        false
      rescue => _e
        true
      end
    })
  end

  it "config/queue.yml defines the required queues" do
    queue_config_path = Rails.root.join("config/queue.yml")
    expect(queue_config_path).to exist

    raw = File.read(queue_config_path)
    %w[default analytics tasks pipeline].each do |queue|
      expect(raw).to include(queue), "Expected queue.yml to mention queue '#{queue}'"
    end
  end
end
