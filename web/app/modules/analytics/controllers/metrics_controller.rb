# frozen_string_literal: true

module Analytics
  class MetricsController < ApplicationController
    before_action :authenticate!

    # GET /api/analytics/llm
    # Returns cost/tokens aggregated by provider and model, filterable by date range.
    def llm
      scope = LlmMetric.where(org_id: current_org_id)
      scope = scope.where('created_at >= ?', Date.parse(params[:from])) if params[:from].present?
      scope = scope.where('created_at <= ?', Date.parse(params[:to]).end_of_day) if params[:to].present?

      rows = scope
        .group(:provider, :model)
        .select(
          :provider,
          :model,
          'SUM(input_tokens) AS total_input_tokens',
          'SUM(output_tokens) AS total_output_tokens',
          'SUM(cost_estimate_usd) AS total_cost_usd'
        )

      render json: rows.map { |r|
        {
          provider: r.provider,
          model: r.model,
          total_input_tokens: r.total_input_tokens,
          total_output_tokens: r.total_output_tokens,
          total_cost_usd: r.total_cost_usd.to_f
        }
      }
    end

    # GET /api/analytics/loops
    # Returns run counts and failure rates by mode.
    def loops
      rows = Agents::AgentRun
        .where(org_id: current_org_id)
        .group(:mode)
        .select(
          :mode,
          'COUNT(*) AS total_runs',
          "SUM(CASE WHEN status = 'failed' THEN 1 ELSE 0 END) AS failed_runs"
        )

      render json: rows.map { |r|
        total = r.total_runs.to_i
        failed = r.failed_runs.to_i
        {
          mode: r.mode,
          total_runs: total,
          failed_runs: failed,
          failure_rate: total.positive? ? (failed.to_f / total).round(4) : 0.0
        }
      }
    end

    # GET /api/analytics/summary
    # Returns weekly totals: cost, tasks completed, loop error rate.
    def summary
      week_start = Time.current.beginning_of_week

      total_cost = LlmMetric
        .where(org_id: current_org_id)
        .where('created_at >= ?', week_start)
        .sum(:cost_estimate_usd)
        .to_f

      runs = Agents::AgentRun
        .where(org_id: current_org_id)
        .where('created_at >= ?', week_start)

      total_runs = runs.count
      failed_runs = runs.where(status: 'failed').count
      completed_runs = runs.where(status: 'completed').count

      render json: {
        week_start: week_start.iso8601,
        total_cost_usd: total_cost,
        completed_runs: completed_runs,
        total_runs: total_runs,
        loop_error_rate: total_runs.positive? ? (failed_runs.to_f / total_runs).round(4) : 0.0
      }
    end
  end
end
