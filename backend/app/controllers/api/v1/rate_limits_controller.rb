class Api::V1::RateLimitsController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_admin_access

  # GET /api/v1/rate_limits/status
  # Get current rate limit status for the authenticated user or IP
  def status
    status_data = {
      user_limits: get_user_rate_limit_status,
      ip_limits: get_ip_rate_limit_status,
      global_limits: get_global_rate_limit_status,
      timestamp: Time.current.iso8601
    }

    render json: { status: 'success', data: status_data }
  end

  # GET /api/v1/rate_limits/analytics
  # Get rate limiting analytics and metrics
  def analytics
    analytics_data = {
      total_requests_today: get_daily_request_count,
      rate_limited_requests_today: get_daily_rate_limited_count,
      top_ips: get_top_requesting_ips,
      top_users: get_top_requesting_users,
      endpoint_usage: get_endpoint_usage_stats
    }

    render json: { status: 'success', data: analytics_data }
  end

  # POST /api/v1/rate_limits/reset
  # Reset rate limits for a specific IP or user (admin only)
  def reset
    target = params[:target] # 'ip' or 'user'
    identifier = params[:identifier] # IP address or user ID

    case target
    when 'ip'
      reset_ip_rate_limits(identifier)
      render json: { status: 'success', message: "Rate limits reset for IP: #{identifier}" }
    when 'user'
      reset_user_rate_limits(identifier)
      render json: { status: 'success', message: "Rate limits reset for user: #{identifier}" }
    else
      render json: { error: 'Invalid target. Use "ip" or "user"' }, status: :bad_request
    end
  rescue => e
    render json: { error: "Failed to reset rate limits: #{e.message}" }, status: :internal_server_error
  end

  # GET /api/v1/rate_limits/config
  # Get current rate limiting configuration
  def config
    config_data = {
      enabled: ENV.fetch('RATE_LIMITING_ENABLED', 'true') == 'true',
      global_limit: ENV.fetch('GLOBAL_RATE_LIMIT', '10000').to_i,
      per_ip_limit: ENV.fetch('PER_IP_RATE_LIMIT', '300').to_i,
      user_limit: ENV.fetch('AUTHENTICATED_USER_LIMIT', '1000').to_i,
      premium_user_limit: ENV.fetch('PREMIUM_USER_LIMIT', '2000').to_i,
      burst_limit: ENV.fetch('BURST_RATE_LIMIT', '30').to_i,
      redis_config: {
        host: ENV.fetch('REDIS_HOST', 'localhost'),
        port: ENV.fetch('REDIS_PORT', '6379').to_i,
        db: ENV.fetch('REDIS_RATE_LIMIT_DB', '1').to_i
      }
    }

    render json: { status: 'success', data: config_data }
  end

  private

  def ensure_admin_access
    unless current_user&.admin?
      render json: { error: 'Admin access required' }, status: :forbidden
    end
  end

  def get_user_rate_limit_status
    return {} unless current_user

    cache_key = "rate_limit:user:#{current_user.id}:#{Time.current.hour}"
    current_count = Rails.cache.read(cache_key) || 0
    limit = get_user_limit(current_user)

    {
      limit: limit,
      used: current_count,
      remaining: [limit - current_count, 0].max,
      reset_time: Time.current.end_of_hour.to_i,
      subscription_tier: current_user.subscription_tier
    }
  end

  def get_ip_rate_limit_status
    cache_key = "rate_limit:ip:#{request.remote_ip}:#{Time.current.hour}"
    current_count = Rails.cache.read(cache_key) || 0
    limit = ENV.fetch('PER_IP_RATE_LIMIT', '300').to_i

    {
      limit: limit,
      used: current_count,
      remaining: [limit - current_count, 0].max,
      reset_time: Time.current.end_of_hour.to_i,
      ip: request.remote_ip
    }
  end

  def get_global_rate_limit_status
    cache_key = "rate_limit:global:#{Time.current.hour}"
    current_count = Rails.cache.read(cache_key) || 0
    limit = ENV.fetch('GLOBAL_RATE_LIMIT', '10000').to_i

    {
      limit: limit,
      used: current_count,
      remaining: [limit - current_count, 0].max,
      reset_time: Time.current.end_of_hour.to_i
    }
  end

  def get_user_limit(user)
    base_limit = ENV.fetch('AUTHENTICATED_USER_LIMIT', '1000').to_i
    
    case user.subscription_tier
    when 'premium'
      ENV.fetch('PREMIUM_USER_LIMIT', '2000').to_i
    when 'enterprise'
      base_limit * 10 # 10x limit for enterprise
    else
      base_limit
    end
  end

  def get_daily_request_count
    # This would typically come from your logging/monitoring system
    # For now, return a placeholder
    Rails.cache.read('daily_request_count') || 0
  end

  def get_daily_rate_limited_count
    Rails.cache.read('daily_rate_limited_count') || 0
  end

  def get_top_requesting_ips(limit = 10)
    # This would typically come from your analytics database
    # For now, return a placeholder
    []
  end

  def get_top_requesting_users(limit = 10)
    # This would typically come from your analytics database
    # For now, return a placeholder
    []
  end

  def get_endpoint_usage_stats
    # This would typically come from your analytics database
    # For now, return a placeholder
    {}
  end

  def reset_ip_rate_limits(ip_address)
    return unless ip_address.present?

    current_hour = Time.current.hour
    cache_patterns = [
      "rate_limit:ip:#{ip_address}:#{current_hour}",
      "rate_limit:ip:#{ip_address}:*"
    ]

    cache_patterns.each do |pattern|
      Rails.cache.delete(pattern)
    end

    # Also clear Rack::Attack cache
    Rack::Attack.cache.delete("requests_per_ip:#{ip_address}")
    Rack::Attack.cache.delete("requests_per_ip_short:#{ip_address}")
  end

  def reset_user_rate_limits(user_id)
    return unless user_id.present?

    user = User.find(user_id)
    current_hour = Time.current.hour
    
    cache_patterns = [
      "rate_limit:user:#{user_id}:#{current_hour}",
      "rate_limit:user:#{user_id}:*"
    ]

    cache_patterns.each do |pattern|
      Rails.cache.delete(pattern)
    end

    # Also clear Rack::Attack cache
    Rack::Attack.cache.delete("user:#{user_id}")
    Rack::Attack.cache.delete("premium_user:#{user_id}") if user.premium? || user.enterprise?
  end
end
