# frozen_string_literal: true

module Analytics
  class DashboardController < ApplicationController
    before_action :authenticate!

    # GET /analytics
    def index
      week_start = Time.current.beginning_of_week

      org_scope = current_org_id

      weekly_metrics = LlmMetric
                       .where(org_id: org_scope)
                       .where('created_at >= ?', week_start)

      @total_cost_this_week = weekly_metrics.sum(:cost_estimate_usd).to_f

      weekly_runs = Agents::AgentRun
                    .where(org_id: org_scope)
                    .where('created_at >= ?', week_start)

      @total_runs = weekly_runs.count
      failed_count = weekly_runs.where(status: 'failed').count
      @failure_rate = @total_runs.positive? ? (failed_count.to_f / @total_runs).round(4) : 0.0

      @cost_by_provider_model = LlmMetric
                                .where(org_id: org_scope)
                                .group(:provider, :model)
                                .select(
                                  :provider,
                                  :model,
                                  'SUM(input_tokens) AS total_input_tokens',
                                  'SUM(output_tokens) AS total_output_tokens',
                                  'SUM(cost_estimate_usd) AS total_cost_usd'
                                )

      @recent_runs = Agents::AgentRun
                     .where(org_id: org_scope)
                     .order(created_at: :desc)
                     .limit(20)
    end

    # GET /analytics/llm
    def llm
      @from = params[:from]
      @to = params[:to]

      scope = LlmMetric.where(org_id: current_org_id)
      scope = scope.where('created_at >= ?', Date.parse(@from)) if @from.present?
      scope = scope.where('created_at <= ?', Date.parse(@to).end_of_day) if @to.present?

      @rows = scope
              .group(:provider, :model)
              .select(
                :provider,
                :model,
                'SUM(input_tokens) AS total_input_tokens',
                'SUM(output_tokens) AS total_output_tokens',
                'SUM(cost_estimate_usd) AS total_cost_usd'
              )
    end
  end
end
