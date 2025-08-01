class ApplicationController < ActionController::API
  include ActionController::Helpers
  
  before_action :configure_permitted_parameters, if: :devise_controller?
  
  # JWT Authentication
  attr_reader :current_user

  def authenticate_user!
    token = extract_token_from_header
    
    if token
      begin
        decoded_token = JWT.decode(token, Rails.application.secrets.secret_key_base, true, algorithm: 'HS256')
        user_id = decoded_token[0]['user_id']
        @current_user = User.find(user_id)
        
        unless @current_user&.active_for_authentication?
          render json: { error: 'Account is not active' }, status: :unauthorized
          return
        end
      rescue JWT::DecodeError, JWT::ExpiredSignature
        render json: { error: 'Invalid or expired token' }, status: :unauthorized
        return
      rescue ActiveRecord::RecordNotFound
        render json: { error: 'User not found' }, status: :unauthorized
        return
      end
    else
      render json: { error: 'Authentication token required' }, status: :unauthorized
      return
    end
  end

  def current_user
    @current_user
  end

  def user_signed_in?
    current_user.present?
  end

  # Health check endpoint for the root path
  def health
    render json: { 
      status: 'ok', 
      service: 'Digital Freight Matching API',
      version: '1.0.0',
      timestamp: Time.current.iso8601,
      environment: Rails.env
    }
  end
  
  protected

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up, keys: [:first_name, :last_name, :phone, :user_type])
    devise_parameter_sanitizer.permit(:account_update, keys: [:first_name, :last_name, :phone])
  end
  
  def render_error(message, status = :unprocessable_entity)
    render json: { error: message }, status: status
  end
  
  def render_success(data = {}, message = 'Success')
    render json: { message: message, data: data }
  end

  private

  def extract_token_from_header
    auth_header = request.headers['Authorization']
    return nil unless auth_header&.start_with?('Bearer ')
    
    auth_header.split(' ').last
  end
end
