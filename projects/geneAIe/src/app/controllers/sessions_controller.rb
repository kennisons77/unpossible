class SessionsController < ApplicationController
  skip_before_action :require_authentication, only: %i[new create]

  def new
  end

  def create
    user = User.authenticate_by(email_address: params[:email_address], password: params[:password])

    if user
      start_new_session_for(user)
      redirect_to root_path, notice: "Signed in successfully."
    else
      redirect_to new_session_path, alert: "Invalid email or password."
    end
  end

  def destroy
    terminate_session
    redirect_to new_session_path, notice: "Signed out."
  end
end
