class DocumentsController < ApplicationController
  def index
    @documents = Document.includes(:concern, :owner).order(created_at: :desc)
  end

  def show
    @document = Document.find(params[:id])
  end
end
