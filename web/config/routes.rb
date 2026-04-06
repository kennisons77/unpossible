# frozen_string_literal: true

Rails.application.routes.draw do
  # Health check — Rails 8 default, unauthenticated
  get 'up' => 'rails/health#show', as: :rails_health_check

  namespace :api do
    # Auth
    post 'auth/token', to: 'auth#create'
  end

  # Ledger nodes — Ledger::NodesController
  get    '/api/nodes',          to: 'ledger/nodes#index',   as: :api_nodes
  post   '/api/nodes',          to: 'ledger/nodes#create'
  get    '/api/nodes/:id',      to: 'ledger/nodes#show',    as: :api_node
  post   '/api/nodes/:id/verdict',  to: 'ledger/nodes#verdict',  as: :verdict_api_node
  post   '/api/nodes/:id/comments', to: 'ledger/nodes#comment',  as: :comments_api_node
end
