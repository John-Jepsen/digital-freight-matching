class ApplicationController < ActionController::API
  include ActionController::Helpers
  
  # Health check endpoint for the root path
  def health
    render json: { 
      status: 'ok', 
      service: 'Digital Freight Matching API',
      version: '1.0.0',
      timestamp: Time.current.iso8601
    }
  end
  
  protected
  
  def render_error(message, status = :unprocessable_entity)
    render json: { error: message }, status: status
  end
  
  def render_success(data = {}, message = 'Success')
    render json: { message: message, data: data }
  end
end
