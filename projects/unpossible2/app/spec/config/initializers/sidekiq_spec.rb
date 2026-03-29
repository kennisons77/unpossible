# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Sidekiq configuration' do # rubocop:disable RSpec/DescribeClass
  it 'connects to Redis without error' do
    expect { Sidekiq::Client.push('class' => 'TestWorker', 'queue' => 'default', 'args' => []) }
      .not_to raise_error
  end

  it 'defines the expected queues' do
    config = YAML.load_file(Rails.root.join('config/sidekiq.yml'))
    expect(config[:queues]).to include('default', 'knowledge', 'analytics', 'tasks')
  end

  it 'mounts Sidekiq web UI at /sidekiq' do
    expect(Rails.application.routes.url_helpers.sidekiq_web_path).to eq('/sidekiq')
  end
end
