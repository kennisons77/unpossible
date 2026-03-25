class ConcernsController < ApplicationController
  before_action :require_authentication

  def index
    @concerns = Concern.includes(:owner).order(:name)
  end

  def show
    @concern = Concern.find(params[:id])
    @documents = @concern.documents.includes(:owner).order(created_at: :desc)
  end

  def confirm
    @concern = Concern.find(params[:id])
    @concern.confirm!
    redirect_to concern_path(@concern), notice: 'Concern confirmed.'
  end
end
