require 'rails_helper'

RSpec.describe 'Documents', type: :request do
  let(:user) { create(:user) }
  let!(:document) { create(:document, owner: user) }

  describe 'GET /documents' do
    context 'when authenticated' do
      before { sign_in(user) }

      it 'returns 200' do
        get documents_path
        expect(response).to have_http_status(:ok)
      end

      it 'lists documents' do
        get documents_path
        expect(response.body).to include(document.id.to_s)
      end
    end

    context 'when not authenticated' do
      it 'redirects to login' do
        get documents_path
        expect(response).to redirect_to(new_session_path)
      end
    end
  end

  describe 'GET /documents/:id' do
    context 'when authenticated' do
      before { sign_in(user) }

      it 'returns 200' do
        get document_path(document)
        expect(response).to have_http_status(:ok)
      end

      it 'displays document details' do
        get document_path(document)
        expect(response.body).to include("Document ##{document.id}")
      end
    end

    context 'when not authenticated' do
      it 'redirects to login' do
        get document_path(document)
        expect(response).to redirect_to(new_session_path)
      end
    end
  end
end
