# frozen_string_literal: true

require 'sidekiq/web'

Rails.application.routes.draw do
  # Health check — Rails 8 default, unauthenticated
  get 'up' => 'rails/health#show', as: :rails_health_check

  # Sidekiq web UI — HTTP Basic Auth in production; open in dev/test
  if Rails.env.production?
    http_basic_authenticate_with(
      name: ENV.fetch('SIDEKIQ_WEB_USER', 'admin'),
      password: ENV.fetch('SIDEKIQ_WEB_PASSWORD'),
      only: :sidekiq_web
    )
  end
  mount Sidekiq::Web => '/sidekiq', as: :sidekiq_web

  namespace :api do
    # Auth
    post 'auth/token', to: 'auth#create'
  end
end
