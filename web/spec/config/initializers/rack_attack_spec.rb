# frozen_string_literal: true

require "rails_helper"

RSpec.describe Rack::Attack, type: :request do
  before { Rack::Attack.reset! }
  after  { Rack::Attack.reset! }

  describe "req/ip throttle (300 req / 5 min)" do
    it "allows requests under the limit" do
      get "/up", headers: { "REMOTE_ADDR" => "1.2.3.4" }
      expect(response.status).not_to eq(429)
    end

    it "returns 429 when limit is exceeded" do
      301.times { get "/up", headers: { "REMOTE_ADDR" => "1.2.3.5" } }
      expect(response.status).to eq(429)
    end

    it "returns JSON error body on throttle" do
      301.times { get "/up", headers: { "REMOTE_ADDR" => "1.2.3.6" } }
      expect(response.body).to include("Too Many Requests")
    end

    it "does not throttle a different IP" do
      301.times { get "/up", headers: { "REMOTE_ADDR" => "1.2.3.7" } }
      get "/up", headers: { "REMOTE_ADDR" => "1.2.3.8" }
      expect(response.status).not_to eq(429)
    end
  end

  describe "auth/ip throttle (10 req / 1 min)" do
    it "returns 429 after exceeding auth limit" do
      # First 10 requests pass through rack-attack (controller may not exist yet — ignore errors)
      10.times do
        begin
          post "/api/auth/token",
               params: {}.to_json,
               headers: { "REMOTE_ADDR" => "2.2.2.2", "CONTENT_TYPE" => "application/json" }
        rescue StandardError
          nil
        end
      end
      # 11th request must be intercepted by rack-attack before reaching the controller
      post "/api/auth/token",
           params: {}.to_json,
           headers: { "REMOTE_ADDR" => "2.2.2.2", "CONTENT_TYPE" => "application/json" }
      expect(response.status).to eq(429)
    end

    it "does not apply auth throttle to non-auth GET requests" do
      # 11 GETs to /up from same IP — only req/ip throttle applies (limit 300)
      11.times { get "/up", headers: { "REMOTE_ADDR" => "2.2.2.3" } }
      expect(response.status).not_to eq(429)
    end
  end
end
