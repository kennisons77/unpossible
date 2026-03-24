# frozen_string_literal: true

class EnrichmentService
  def initialize(document)
    @document = document
  end

  def call
    raise NotImplementedError, "EnrichmentService not yet implemented"
  end
end
