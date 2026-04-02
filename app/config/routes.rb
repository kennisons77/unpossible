# frozen_string_literal: true

Rails.application.routes.draw do
  # Health check — Rails 8 default, unauthenticated
  get 'up' => 'rails/health#show', as: :rails_health_check

  namespace :api do
    # Auth
    post 'auth/token', to: 'auth#create'
  end
end
