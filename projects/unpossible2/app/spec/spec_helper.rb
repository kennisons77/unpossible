# frozen_string_literal: true

require 'simplecov'
SimpleCov.start 'rails' do
  minimum_coverage 90
  add_filter '/spec/'
  add_filter '/config/'
  add_filter '/db/'
  track_files '{app,lib}/**/*.rb'
  # Skip coverage check when there are no examples (empty suite)
  at_exit do
    SimpleCov.result.format!
    if SimpleCov.result.covered_percent < SimpleCov.minimum_coverage[:line] &&
       RSpec.world.example_count > 0
      warn "Line coverage (#{SimpleCov.result.covered_percent.round(2)}%) is below the expected minimum coverage (#{SimpleCov.minimum_coverage[:line]}%)."
      exit 2
    end
  end
end

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups
  config.filter_run_when_matching :focus
  config.disable_monkey_patching!
  config.warnings = true
  config.order = :random
  Kernel.srand config.seed
end
