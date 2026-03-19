unless Rails.application.credentials.secret_key_base || ENV["SECRET_KEY_BASE"]
  Rails.application.config.secret_key_base = ENV.fetch("SECRET_KEY_BASE") {
    SecureRandom.hex(64) if Rails.env.local?
  }
end
