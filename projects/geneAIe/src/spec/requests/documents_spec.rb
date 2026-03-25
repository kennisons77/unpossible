require 'rails_helper'

RSpec.describe 'Documents' do
  let!(:user) { create(:user, email_address: 'admin@sovereign.local', password: 'secure-password') }
  let!(:session) { create(:session, user: user) }

  def authenticate!
    post session_path, params: { email_address: 'admin@sovereign.local', password: 'secure-password' }
  end

  describe 'GET /documents' do
    context 'when authenticated' do
      before { authenticate! }

      it 'returns 200 with documents listed' do
        document = create(:document, owner: user)
        get documents_path
        expect(response).to have_http_status(:ok)
        expect(response.body).to include(document.id.to_s)
      end

      it 'shows empty state when no documents' do
        get documents_path
        expect(response).to have_http_status(:ok)
        expect(response.body).to include('No documents yet')
      end
    end

    context 'when unauthenticated' do
      it 'redirects to login' do
        get documents_path
        expect(response).to redirect_to(new_session_path)
      end
    end
  end

  describe 'GET /documents/:id' do
    let!(:document) { create(:document, owner: user) }

    context 'when authenticated' do
      before { authenticate! }

      it 'returns 200 with metadata and fields' do
        get document_path(document)
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Document ##{document.id}")
      end

      it 'displays document fields with source badges' do
        create(:document_field, document: document, field_name: 'account_number', value: '12345', source: :llm)
        get document_path(document)
        expect(response).to have_http_status(:ok)
        expect(response.body).to include('Account Number')
        expect(response.body).to include('12345')
        expect(response.body).to include('llm')
      end
    end

    context 'when unauthenticated' do
      it 'redirects to login' do
        get document_path(document)
        expect(response).to redirect_to(new_session_path)
      end
    end
  end
end
