# frozen_string_literal: true

Rails.application.routes.draw do
  # Health check — Rails 8 default, unauthenticated
  get 'up' => 'rails/health#show', as: :rails_health_check

  namespace :api do
    # Auth
    post 'auth/token', to: 'auth#create'
  end

  # Agent runs — Agents::AgentRunsController (JSON API)
  post '/api/agent_runs/start',        to: 'agents/agent_runs#start'
  post '/api/agent_runs/:id/complete',  to: 'agents/agent_runs#complete', as: :complete_api_agent_run
  post '/api/agent_runs/:id/input',     to: 'agents/agent_runs#input',    as: :input_api_agent_run

  # Ledger nodes — Ledger::NodesController (JSON API)
  get    '/api/nodes',          to: 'ledger/nodes#index',   as: :api_nodes
  post   '/api/nodes',          to: 'ledger/nodes#create'
  get    '/api/nodes/:id',      to: 'ledger/nodes#show',    as: :api_node
  post   '/api/nodes/:id/verdict',  to: 'ledger/nodes#verdict',  as: :verdict_api_node
  post   '/api/nodes/:id/comments', to: 'ledger/nodes#comment',  as: :comments_api_node

  # Ledger UI — Ledger::LedgerController (HTML)
  scope '/ledger' do
    get '/',        to: 'ledger/ledger#current', as: :ledger_current
    get '/open',    to: 'ledger/ledger#open',    as: :ledger_open
    get '/tree',    to: 'ledger/ledger#tree',    as: :ledger_tree
    get '/nodes/:id', to: 'ledger/ledger#node',  as: :ledger_node
  end

  # Session — stub login page (auth via JWT bearer token)
  get '/session/new', to: proc { [200, {}, ['Login']] }, as: :new_session
end
