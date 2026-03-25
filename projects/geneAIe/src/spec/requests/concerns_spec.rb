require 'rails_helper'

RSpec.describe 'Concerns' do
  let!(:user) { create(:user, email_address: 'admin@sovereign.local', password: 'secure-password') }
  let!(:session) { create(:session, user: user) }

  def authenticate!
    post session_path, params: { email_address: 'admin@sovereign.local', password: 'secure-password' }
  end

  describe 'GET /concerns' do
    context 'when authenticated' do
      before { authenticate! }

      it 'returns 200 with concerns listed' do
        concern = create(:concern, owner: user)
        get concerns_path
        expect(response).to have_http_status(:ok)
        expect(response.body).to include(concern.name)
      end

      it 'shows confirmed status badge' do
        concern = create(:concern, :confirmed, owner: user)
        get concerns_path
        expect(response).to have_http_status(:ok)
        expect(response.body).to include('Confirmed')
      end

      it 'shows unconfirmed status badge' do
        concern = create(:concern, owner: user)
        get concerns_path
        expect(response).to have_http_status(:ok)
        expect(response.body).to include('Unconfirmed')
      end
    end

    context 'when unauthenticated' do
      it 'redirects to login' do
        get concerns_path
        expect(response).to redirect_to(new_session_path)
      end
    end
  end

  describe 'GET /concerns/:id' do
    let!(:concern) { create(:concern, owner: user) }

    context 'when authenticated' do
      before { authenticate! }

      it 'returns 200 with documents' do
        document = create(:document, owner: user, concern: concern)
        get concern_path(concern)
        expect(response).to have_http_status(:ok)
        expect(response.body).to include(concern.name)
        expect(response.body).to include(document.id.to_s)
      end

      it 'shows empty state when no documents' do
        get concern_path(concern)
        expect(response).to have_http_status(:ok)
        expect(response.body).to include('No documents in this concern yet')
      end
    end

    context 'when unauthenticated' do
      it 'redirects to login' do
        get concern_path(concern)
        expect(response).to redirect_to(new_session_path)
      end
    end
  end

  describe 'POST /concerns/:id/confirm' do
    let!(:concern) { create(:concern, owner: user) }

    context 'when authenticated' do
      before { authenticate! }

      it 'sets confirmed_at and redirects' do
        expect(concern.confirmed_at).to be_nil
        post confirm_concern_path(concern)
        expect(response).to redirect_to(concern_path(concern))
        expect(concern.reload.confirmed_at).to be_present
      end
    end

    context 'when unauthenticated' do
      it 'redirects to login' do
        post confirm_concern_path(concern)
        expect(response).to redirect_to(new_session_path)
      end
    end
  end
end
