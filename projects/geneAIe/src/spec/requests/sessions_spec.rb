require "rails_helper"

RSpec.describe "Sessions" do
  let!(:user) { create(:user, email_address: "admin@sovereign.local", password: "secure-password") }

  describe "GET /session/new" do
    it "renders the login form" do
      get new_session_path
      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /session" do
    context "with valid credentials" do
      it "creates a session and redirects to root" do
        post session_path, params: { email_address: "admin@sovereign.local", password: "secure-password" }
        expect(response).to redirect_to(root_path)
        expect(cookies[:session_id]).to be_present
      end
    end

    context "with invalid credentials" do
      it "rejects login and redirects back" do
        post session_path, params: { email_address: "admin@sovereign.local", password: "wrong" }
        expect(response).to redirect_to(new_session_path)
      end
    end

    context "with nonexistent email" do
      it "rejects login and redirects back" do
        post session_path, params: { email_address: "nobody@example.com", password: "anything" }
        expect(response).to redirect_to(new_session_path)
      end
    end
  end

  describe "DELETE /session" do
    it "destroys the session and redirects to login" do
      post session_path, params: { email_address: "admin@sovereign.local", password: "secure-password" }
      delete session_path
      expect(response).to redirect_to(new_session_path)
    end
  end

  describe "authentication requirement" do
    it "redirects unauthenticated requests to login" do
      get root_path
      expect(response).to redirect_to(new_session_path)
    end
  end
end
