# frozen_string_literal: true

module Agents
  class AgentRunsController < ApplicationController
    before_action :authenticate!
    before_action :set_agent_run, only: %i[complete input]

    def start
      result = RunStorageService.start(agent_run_params)
      status = result[:cached] ? :ok : :created
      render json: result[:run], status: status
    rescue RunStorageService::ConcurrentRunError
      render json: { error: "Concurrent run already active for this actor" }, status: :conflict
    rescue RunStorageService::DuplicateRunError
      render json: { error: "Duplicate run_id" }, status: :unprocessable_entity
    rescue ActiveRecord::RecordInvalid => e
      render json: { errors: e.record.errors.full_messages }, status: :unprocessable_entity
    end

    def complete
      unless sidecar_authenticated?
        render json: { error: "Unauthorized" }, status: :unauthorized
        return
      end

      RunStorageService.complete(@agent_run, complete_params)
      render json: @agent_run
    end

    def input
      turn = RunStorageService.record_input(@agent_run, content: params[:content])
      render json: turn
    end

    private

    def set_agent_run
      @agent_run = AgentRun.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      render json: { error: "Not found" }, status: :not_found
    end

    def sidecar_authenticated?
      sidecar_token.present? && sidecar_token == sidecar_secret
    end

    def agent_run_params
      params.permit(
        :run_id, :source_ref, :parent_run_id,
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
