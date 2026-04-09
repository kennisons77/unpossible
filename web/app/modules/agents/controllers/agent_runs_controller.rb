# frozen_string_literal: true

module Agents
  class AgentRunsController < ApplicationController
    before_action :authenticate!
    before_action :set_agent_run, only: %i[complete input]

    # POST /api/agent_runs/start
    def start
      # Dedup check
      if params[:prompt_sha256].present? && params[:mode].present?
        cached = PromptDeduplicator.call(
          prompt_sha256: params[:prompt_sha256],
          mode: params[:mode]
        )
        if cached
          render json: cached, status: :ok
          return
        end
      end

      # Concurrent run check — one active run per actor
      if AgentRun.where(actor_id: params[:actor_id], status: %w[running waiting_for_input]).exists?
        render json: { error: 'Concurrent run already active for this actor' }, status: :conflict
        return
      end

      run = AgentRun.new(agent_run_params.merge(status: 'running'))
      if run.save
        render json: run, status: :created
      else
        if run.errors[:run_id]&.include?('has already been taken')
          render json: { error: 'Duplicate run_id' }, status: :unprocessable_entity
        else
          render json: { errors: run.errors.full_messages }, status: :unprocessable_entity
        end
      end
    end

    # POST /api/agent_runs/:id/complete
    def complete
      unless sidecar_authenticated?
        render json: { error: 'Unauthorized' }, status: :unauthorized
        return
      end

      @agent_run.update!(complete_params.merge(status: 'completed'))
      render json: @agent_run
    end

    # POST /api/agent_runs/:id/input
    def input
      turn = @agent_run.turns.create!(
        position: (@agent_run.turns.maximum(:position) || 0) + 1,
        kind: 'human_input',
        content: params[:content]
      )
      @agent_run.update!(status: 'running')
      render json: turn
    end

    private

    def set_agent_run
      @agent_run = AgentRun.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      render json: { error: 'Not found' }, status: :not_found
    end

    def sidecar_authenticated?
      sidecar_token.present? && sidecar_token == sidecar_secret
    end

    def agent_run_params
      params.permit(
        :run_id, :actor_id, :node_id, :parent_run_id,
        :mode, :provider, :model, :prompt_sha256,
        source_node_ids: []
      )
    end

    def complete_params
      params.permit(
        :input_tokens, :output_tokens, :cost_estimate_usd,
        :duration_ms, :response_truncated
      )
    end
  end
end
