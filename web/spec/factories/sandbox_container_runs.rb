# frozen_string_literal: true

FactoryBot.define do
  factory :sandbox_container_run, class: "Sandbox::ContainerRun" do
    org_id { SecureRandom.uuid }
    image { "ruby:3.3-slim" }
    command { "bundle exec rspec" }
    status { "pending" }
    agent_run { nil }
  end
end
