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

    # GET /api/analytics/events
    # Returns paginated analytics events, filterable by event_name, org_id, and date range.
    def events
      scope = AnalyticsEvent.where(org_id: current_org_id)
      scope = scope.where(event_name: params[:event_name]) if params[:event_name].present?
      scope = scope.where('timestamp >= ?', Time.parse(params[:from])) if params[:from].present?
      scope = scope.where('timestamp <= ?', Time.parse(params[:to])) if params[:to].present?

      page     = [params.fetch(:page, 1).to_i, 1].max
      per_page = [params.fetch(:per_page, 50).to_i, 200].min

      total  = scope.count
      events = scope.order(timestamp: :desc).offset((page - 1) * per_page).limit(per_page)

      render json: {
        total: total,
        page: page,
        per_page: per_page,
        events: events.map { |e|
          {
            id: e.id,
            event_name: e.event_name,
            distinct_id: e.distinct_id,
            node_id: e.node_id,
            properties: e.properties,
            timestamp: e.timestamp.iso8601,
            received_at: e.received_at.iso8601
          }
        }
      }
    end

    # GET /api/analytics/flags/:key
    # Returns exposure counts and conversion rates per variant for a feature flag.
    def flag_stats
      key = params[:key]

      exposures = AnalyticsEvent
        .where(org_id: current_org_id, event_name: '$feature_flag_called')
        .where("properties->>'flag_key' = ?", key)

      by_variant = exposures.group("properties->>'variant'").count

      # Conversion: any event from the same distinct_id after the exposure
      conversion_rates = by_variant.keys.each_with_object({}) do |variant, acc|
        exposed_ids = exposures
          .where("properties->>'variant' = ?", variant)
          .pluck(:distinct_id)

        next acc[variant] = 0.0 if exposed_ids.empty?

        converted = AnalyticsEvent
          .where(org_id: current_org_id)
          .where(distinct_id: exposed_ids)
          .where.not(event_name: '$feature_flag_called')
          .select(:distinct_id).distinct.count

        acc[variant] = (converted.to_f / exposed_ids.size).round(4)
      end

      render json: {
        flag_key: key,
        variants: by_variant.map { |variant, count|
          {
            variant: variant,
            exposure_count: count,
            conversion_rate: conversion_rates[variant] || 0.0
          }
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
