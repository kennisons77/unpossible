# frozen_string_literal: true

class ApplicationJob < ActiveJob::Base
  retry_on ActiveJob::DeserializationError
end
