require 'rails_helper'

RSpec.describe 'Concerns', type: :request do
  let(:user) { create(:user) }
  let!(:concern) { create(:concern, owner: user, llm_proposed: true, confirmed_at: nil) }

  describe 'GET /concerns' do
    context 'when authenticated' do
      before { sign_in(user) }

      it 'returns 200' do
        get concerns_path
        expect(response).to have_http_status(:ok)
      end

      it 'lists concerns' do
        get concerns_path
        expect(response.body).to include(concern.name)
      end
    end

    context 'when not authenticated' do
      it 'redirects to login' do
        get concerns_path
        expect(response).to redirect_to(new_session_path)
      end
    end
  end

  describe 'GET /concerns/:id' do
    context 'when authenticated' do
      before { sign_in(user) }

      it 'returns 200' do
        get concern_path(concern)
        expect(response).to have_http_status(:ok)
      end

      it 'displays concern with documents' do
        get concern_path(concern)
        expect(response.body).to include(concern.name)
      end
    end

    context 'when not authenticated' do
      it 'redirects to login' do
        get concern_path(concern)
        expect(response).to redirect_to(new_session_path)
      end
    end
  end

  describe 'PATCH /concerns/:id/confirm' do
    context 'when authenticated' do
      before { sign_in(user) }

      it 'confirms the concern' do
        expect do
          patch confirm_concern_path(concern)
        end.to change { concern.reload.confirmed_at }.from(nil)
      end

      it 'redirects to concern show' do
        patch confirm_concern_path(concern)
        expect(response).to redirect_to(concern_path(concern))
      end

      it 'sets confirmed_at timestamp' do
        patch confirm_concern_path(concern)
        expect(concern.reload.confirmed?).to be true
      end
    end

    context 'when not authenticated' do
      it 'redirects to login' do
        patch confirm_concern_path(concern)
        expect(response).to redirect_to(new_session_path)
      end
    end
  end
end
