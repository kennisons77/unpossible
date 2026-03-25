class DocumentsController < ApplicationController
  before_action :require_authentication

  def index
    @documents = Document.includes(:concern, :owner).order(created_at: :desc)
  end

  def show
    @document = Document.includes(:concern, :document_fields).find(params[:id])
  end
end
