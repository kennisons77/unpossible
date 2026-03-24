# frozen_string_literal: true

class StorageService
  def initialize(document)
    @document = document
  end

  def call
    raise NotImplementedError, "StorageService not yet implemented"
  end
end
