# frozen_string_literal: true

class NormalizationService
  def initialize(document)
    @document = document
  end

  def call
    raise NotImplementedError, "NormalizationService not yet implemented"
  end
end
