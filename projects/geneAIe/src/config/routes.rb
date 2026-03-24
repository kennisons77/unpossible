# frozen_string_literal: true

Rails.application.routes.draw do
  resource :session, only: %i[new create destroy]

  get "up" => "rails/health#show", as: :rails_health_check

  root "dashboard#show"
end
