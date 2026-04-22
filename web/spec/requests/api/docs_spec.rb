# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'GET /api/docs', type: :request, spec: "specifications/system/api/concept.md#api-docs" do
  it 'returns 200 without authentication' do
    get '/api/docs/index.html'
    expect(response).to have_http_status(:ok)
  end
end
