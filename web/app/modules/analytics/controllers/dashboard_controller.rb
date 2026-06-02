# frozen_string_literal: true

module Analytics
  class DashboardController < ApplicationController
    before_action :authenticate!

    # GET /analytics
    def index
      week_start = Time.current.beginning_of_week

      @total_cost_usd = LlmMetric
        .where(org_id: current_org_id)
        .where('created_at >= ?', week_start)
        .sum(:cost_estimate_usd)
        .to_f

      runs = Agents::AgentRun.where(org_id: current_org_id)
      week_runs = runs.where('created_at >= ?', week_start)

      @total_runs   = week_runs.count
      @failed_runs  = week_runs.where(status: 'failed').count
      @failure_rate = @total_runs.positive? ? (@failed_runs.to_f / @total_runs * 100).round(1) : 0.0

      @cost_by_provider = LlmMetric
        .where(org_id: current_org_id)
        .group(:provider, :model)
        .select(:provider, :model,
                'SUM(cost_estimate_usd) AS total_cost_usd',
                'SUM(input_tokens) AS total_input_tokens',
                'SUM(output_tokens) AS total_output_tokens',
                'COUNT(*) AS call_count')
        .order('total_cost_usd DESC')

      @recent_runs = runs.order(created_at: :desc).limit(20)
    end

    # GET /analytics/llm
    def llm
      scope = LlmMetric.where(org_id: current_org_id)
      scope = scope.where('created_at >= ?', Date.parse(params[:from]).beginning_of_day) if params[:from].present?
      scope = scope.where('created_at <= ?', Date.parse(params[:to]).end_of_day) if params[:to].present?

      @rows = scope
        .group(:provider, :model)
        .select(:provider, :model,
                'SUM(cost_estimate_usd) AS total_cost_usd',
                'SUM(input_tokens) AS total_input_tokens',
                'SUM(output_tokens) AS total_output_tokens',
                'COUNT(*) AS call_count')
        .order('total_cost_usd DESC')

      @from = params[:from]
      @to   = params[:to]
    end
  end
end
