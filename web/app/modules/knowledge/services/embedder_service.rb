# frozen_string_literal: true

module Knowledge
  class EmbedderService
    PROVIDERS = {
      "openai" => "Knowledge::OpenAiEmbedder"
    }.freeze

    def self.for(provider = ENV.fetch("EMBEDDER_PROVIDER", "openai"))
      klass_name = PROVIDERS[provider]
      raise NotImplementedError, "Embedder provider '#{provider}' is not implemented" unless klass_name

      klass_name.constantize.new
    end

    # Subclasses implement: embed(text) → Array<Float>
    def embed(_text)
      raise NotImplementedError, "#{self.class}#embed must be implemented"
    end
  end
end
