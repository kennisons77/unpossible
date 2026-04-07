# frozen_string_literal: true

module Ledger
  class NodesController < ApplicationController
    before_action :authenticate!
    before_action :set_node, only: %i[show verdict comment]

    # GET /api/nodes
    def index
      nodes = Ledger::Node.all
      nodes = nodes.where(scope: params[:scope]) if params[:scope].present?
      nodes = nodes.where(status: params[:status]) if params[:status].present?
      nodes = nodes.where(resolution: params[:resolution]) if params[:resolution].present?
      nodes = nodes.where(author: params[:author]) if params[:author].present?

      if params[:parent_id].present?
        child_ids = Ledger::NodeEdge.where(parent_id: params[:parent_id]).pluck(:child_id)
        nodes = nodes.where(id: child_ids)
      end

      render json: nodes
    end

    # POST /api/nodes
    def create
      node = Ledger::Node.new(node_params)
      if node.save
        render json: node, status: :created
      else
        render json: { errors: node.errors.full_messages }, status: :unprocessable_entity
      end
    end

    # GET /api/nodes/:id
    def show
      render json: @node
    end

    # POST /api/nodes/:id/verdict
    def verdict
      verdict_value = ActiveModel::Type::Boolean.new.cast(params[:verdict])
      accepted_by_id = params[:accepted_by_id] || current_user_id

      Ledger::NodeLifecycleService.record_verdict(@node, verdict_value, accepted_by_id: accepted_by_id)
      render json: @node.reload
    rescue Ledger::NodeLifecycleService::LifecycleError => e
      render json: { error: e.message }, status: :unprocessable_entity
    end

    # POST /api/nodes/:id/comments
    def comment
      if @node.kind == 'answer'
        render json: { error: 'answer nodes are immutable after creation' }, status: :unprocessable_entity
        return
      end

      Knowledge::IndexerJob.perform_later(@node.id.to_s) if defined?(Knowledge::IndexerJob)
      render json: { status: 'queued' }
    end

    private

    def set_node
      @node = Ledger::Node.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      render json: { error: 'Not found' }, status: :not_found
    end

    def node_params
      params.require(:node).permit(
        :kind, :answer_type, :scope, :body, :title, :spec_path,
        :author, :stable_ref, :status, :resolution,
        :org_id, :recorded_at, :originated_at
      )
    end
  end
end
