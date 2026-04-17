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

  # Feature flags — Analytics::FeatureFlagsController (JSON API)
  get   '/api/feature_flags',      to: 'analytics/feature_flags#index'
  post  '/api/feature_flags',      to: 'analytics/feature_flags#create'
  patch '/api/feature_flags/:key', to: 'analytics/feature_flags#update', as: :api_feature_flag,
        constraints: { key: /[^\/]+/ }

  # Analytics metrics — Analytics::MetricsController (JSON API)
  get '/api/analytics/llm',          to: 'analytics/metrics#llm'
  get '/api/analytics/loops',        to: 'analytics/metrics#loops'
  get '/api/analytics/summary',      to: 'analytics/metrics#summary'
  get '/api/analytics/events',       to: 'analytics/metrics#events'
  get '/api/analytics/flags/:key',   to: 'analytics/metrics#flag_stats', as: :api_analytics_flag_stats,
      constraints: { key: /[^\/]+/ }
end
