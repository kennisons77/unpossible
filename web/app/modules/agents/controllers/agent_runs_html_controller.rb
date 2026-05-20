# frozen_string_literal: true

module Agents
  class AgentRunsHtmlController < ApplicationController
    include MarkdownHelper
    before_action :authenticate!

    PER_PAGE = 25

    def index
      scope = AgentRun.order(created_at: :desc)
      scope = scope.where(mode: params[:mode]) if params[:mode].present?
      scope = scope.where(status: params[:status]) if params[:status].present?

      @page = [params.fetch(:page, 1).to_i, 1].max
      @total = scope.count
      @runs = scope.limit(PER_PAGE).offset((@page - 1) * PER_PAGE)
      @total_pages = (@total.to_f / PER_PAGE).ceil
    end

    def show
      @run = AgentRun.find(params[:id])
      @turns = @run.turns.order(:position)
    rescue ActiveRecord::RecordNotFound
      render plain: "Not found", status: :not_found
    end
  end
end
