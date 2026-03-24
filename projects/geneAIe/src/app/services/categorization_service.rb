# frozen_string_literal: true

class CategorizationService
  def initialize(document)
    @document = document
  end

  def call
    raise NotImplementedError, "CategorizationService not yet implemented"
  end
end
