# frozen_string_literal: true

# Wraps a sensitive value so it never leaks into logs, inspect output, or JSON.
# Use .expose to retrieve the raw value only at the point of actual use.
class Secret
  def initialize(value)
    @value = value
  end

  def inspect
    '[REDACTED]'
  end

  def to_s
    '[REDACTED]'
  end

  def as_json(*)
    '[REDACTED]'
  end

  def to_json(*)
    '"[REDACTED]"'
  end

  # Returns the raw value. Call only at the boundary where the secret is consumed.
  def expose
    @value
  end
end
