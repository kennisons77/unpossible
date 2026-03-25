Rails.application.routes.draw do
  resource :session, only: %i[new create destroy]

  resources :documents, only: %i[index show]
  resources :concerns, only: %i[index show] do
    member do
      post :confirm
    end
  end

  get "up" => "rails/health#show", as: :rails_health_check

  root "dashboard#show"
end
