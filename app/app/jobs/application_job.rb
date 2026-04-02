# frozen_string_literal: true

class ApplicationJob < ActiveJob::Base
  # Retry on transient failures; subclasses can override
  retry_on StandardError, wait: :polynomially_longer, attempts: 3
end
