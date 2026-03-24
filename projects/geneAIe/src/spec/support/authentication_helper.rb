module AuthenticationHelper
  def sign_in(user)
    session = user.sessions.create!(user_agent: 'test', ip_address: '127.0.0.1')
    allow_any_instance_of(ApplicationController).to receive(:find_session_by_cookie).and_return(session)
  end
end

RSpec.configure do |config|
  config.include AuthenticationHelper, type: :request
end
