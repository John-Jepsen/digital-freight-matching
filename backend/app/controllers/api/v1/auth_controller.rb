class Api::V1::AuthController < ApplicationController
  before_action :authenticate_user!, except: [:login, :register]

  # POST /api/v1/auth/register
  def register
    @user = User.new(user_params)
    
    if @user.save
      token = generate_jwt_token(@user)
      render json: {
        message: 'User created successfully',
        user: user_response(@user),
        token: token
      }, status: :created
    else
      render json: {
        error: 'Registration failed',
        details: @user.errors.full_messages
      }, status: :unprocessable_entity
    end
  end

  # POST /api/v1/auth/login
  def login
    @user = User.find_by(email: params[:email]&.downcase)
    
    if @user&.valid_password?(params[:password])
      if @user.active_for_authentication?
        @user.update(
          sign_in_count: @user.sign_in_count + 1,
          current_sign_in_at: Time.current,
          last_sign_in_at: @user.current_sign_in_at,
          current_sign_in_ip: request.remote_ip,
          last_sign_in_ip: @user.current_sign_in_ip
        )
        
        token = generate_jwt_token(@user)
        render json: {
          message: 'Login successful',
          user: user_response(@user),
          token: token
        }, status: :ok
      else
        render json: {
          error: 'Account is not active'
        }, status: :unauthorized
      end
    else
      render json: {
        error: 'Invalid email or password'
      }, status: :unauthorized
    end
  end

  # DELETE /api/v1/auth/logout
  def logout
    # JWT is stateless, so we just return success
    # In production, you might want to maintain a blacklist of tokens
    render json: {
      message: 'Logged out successfully'
    }, status: :ok
  end

  # GET /api/v1/auth/me
  def me
    render json: {
      user: user_response(current_user)
    }, status: :ok
  end

  # POST /api/v1/auth/refresh
  def refresh
    token = generate_jwt_token(current_user)
    render json: {
      message: 'Token refreshed',
      token: token,
      user: user_response(current_user)
    }, status: :ok
  end

  # POST /api/v1/auth/forgot_password
  def forgot_password
    @user = User.find_by(email: params[:email]&.downcase)
    
    if @user
      @user.send_reset_password_instructions
      render json: {
        message: 'Password reset instructions sent to your email'
      }, status: :ok
    else
      render json: {
        error: 'Email not found'
      }, status: :not_found
    end
  end

  # POST /api/v1/auth/reset_password
  def reset_password
    @user = User.reset_password_by_token(reset_password_params)
    
    if @user.errors.empty?
      token = generate_jwt_token(@user)
      render json: {
        message: 'Password reset successful',
        user: user_response(@user),
        token: token
      }, status: :ok
    else
      render json: {
        error: 'Password reset failed',
        details: @user.errors.full_messages
      }, status: :unprocessable_entity
    end
  end

  private

  def user_params
    params.require(:user).permit(
      :email, :password, :password_confirmation,
      :first_name, :last_name, :phone, :user_type
    )
  end

  def reset_password_params
    params.require(:user).permit(:reset_password_token, :password, :password_confirmation)
  end

  def generate_jwt_token(user)
    payload = {
      user_id: user.id,
      email: user.email,
      user_type: user.user_type,
      exp: 24.hours.from_now.to_i
    }
    
    JWT.encode(payload, Rails.application.secrets.secret_key_base)
  end

  def user_response(user)
    {
      id: user.id,
      email: user.email,
      first_name: user.first_name,
      last_name: user.last_name,
      full_name: user.full_name,
      phone: user.phone,
      user_type: user.user_type,
      status: user.status,
      average_rating: user.average_rating,
      total_ratings: user.total_ratings,
      created_at: user.created_at,
      profile: user.profile&.as_json(except: [:created_at, :updated_at])
    }
  end
end