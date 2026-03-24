# frozen_string_literal: true

class IdentificationService
  def initialize(document)
    @document = document
  end

  def call
    raise NotImplementedError, "IdentificationService not yet implemented"
  end
end
