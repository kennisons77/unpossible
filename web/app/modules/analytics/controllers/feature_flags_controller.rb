# frozen_string_literal: true

module Analytics
  class FeatureFlagsController < ApplicationController
    before_action :authenticate!
    before_action :set_flag, only: [:update]

    def index
      flags = if params[:status] == 'archived'
                FeatureFlag.where(org_id: current_org_id)
              else
                FeatureFlag.where(org_id: current_org_id, status: 'active')
              end
      render json: flags
    end

    def create
      flag = FeatureFlag.new(create_params.merge(status: 'active', enabled: false))
      if flag.save
        render json: flag, status: :created
      else
        render json: { errors: flag.errors.full_messages }, status: :unprocessable_entity
      end
    end

    def update
      if @flag.update(update_params)
        render json: @flag
      else
        render json: { errors: @flag.errors.full_messages }, status: :unprocessable_entity
      end
    end

    private

    def set_flag
      @flag = FeatureFlag.find_by!(key: params[:key], org_id: current_org_id)
    rescue ActiveRecord::RecordNotFound
      render json: { error: 'Not found' }, status: :not_found
    end

    def create_params
      params.permit(:key, :org_id, metadata: {})
    end

    def update_params
      params.permit(:enabled)
    end
  end
end
