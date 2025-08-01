class Api::V1::HealthController < ApplicationController
  def show
    render json: {
      status: 'ok',
      service: 'Digital Freight Matching API',
      version: '1.0.0',
      timestamp: Time.current.iso8601,
      environment: Rails.env,
      database: database_status,
      redis: redis_status
    }
  end
  
  private
  
  def database_status
    ActiveRecord::Base.connection.execute("SELECT 1")
    'connected'
  rescue => e
    'disconnected'
  end
  
  def redis_status
    Rails.cache.fetch('health_check', expires_in: 1.second) { 'ok' }
    'connected'
  rescue => e
    'disconnected'
  end
end