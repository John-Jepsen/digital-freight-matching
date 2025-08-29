# Custom Rate Limiter middleware for advanced features
# Extends Rack::Attack with business-specific rate limiting logic

class RateLimiter
  def initialize(app)
    @app = app
  end

  def call(env)
    request = Rack::Request.new(env)
    
    # Add custom rate limit headers to all API responses
    status, headers, body = @app.call(env)
    
    if request.path.start_with?('/api/')
      add_rate_limit_headers(headers, request)
      log_request_metrics(request, status)
    end

    [status, headers, body]
  end

  private

  def add_rate_limit_headers(headers, request)
    # Get current rate limit status for this request
    limits = calculate_current_limits(request)
    
    headers['X-RateLimit-Limit'] = limits[:limit].to_s
    headers['X-RateLimit-Remaining'] = limits[:remaining].to_s
    headers['X-RateLimit-Reset'] = limits[:reset_time].to_s
    headers['X-RateLimit-Retry-After'] = limits[:retry_after].to_s if limits[:retry_after]
  end

  def calculate_current_limits(request)
    # Default limits - can be customized based on request characteristics
    base_limit = 300 # requests per hour for regular users
    period = 3600 # 1 hour in seconds
    
    # Adjust limits based on user authentication and subscription
    limit = determine_user_limit(request, base_limit)
    
    # Calculate remaining requests using Redis
    cache_key = rate_limit_cache_key(request)
    current_count = Rails.cache.read(cache_key) || 0
    remaining = [limit - current_count, 0].max
    
    # Calculate reset time
    now = Time.current.to_i
    reset_time = now + (period - (now % period))
    
    {
      limit: limit,
      remaining: remaining,
      reset_time: reset_time,
      retry_after: remaining == 0 ? (reset_time - now) : nil
    }
  end

  def determine_user_limit(request, base_limit)
    return base_limit unless request.env['HTTP_AUTHORIZATION']
    
    begin
      token = request.env['HTTP_AUTHORIZATION']&.split(' ')&.last
      return base_limit unless token
      
      decoded_token = JWT.decode(token, Rails.application.secret_key_base, true, algorithm: 'HS256')
      user_id = decoded_token[0]['user_id']
      user = User.find(user_id)
      
      # Adjust limits based on user subscription tier
      case user&.subscription_tier
      when 'premium'
        base_limit * 4 # 1200 requests/hour for premium users
      when 'enterprise'
        base_limit * 10 # 3000 requests/hour for enterprise users
      else
        base_limit # Standard limit
      end
    rescue JWT::DecodeError, JWT::ExpiredSignature, ActiveRecord::RecordNotFound
      base_limit
    end
  end

  def rate_limit_cache_key(request)
    # Create unique cache key based on IP and user (if authenticated)
    ip_key = "ip:#{request.ip}"
    
    if request.env['HTTP_AUTHORIZATION']
      begin
        token = request.env['HTTP_AUTHORIZATION']&.split(' ')&.last
        if token
          decoded_token = JWT.decode(token, Rails.application.secret_key_base, true, algorithm: 'HS256')
          user_id = decoded_token[0]['user_id']
          return "rate_limit:user:#{user_id}:#{Time.current.hour}"
        end
      rescue JWT::DecodeError, JWT::ExpiredSignature
        # Fall back to IP-based limiting
      end
    end
    
    "rate_limit:#{ip_key}:#{Time.current.hour}"
  end

  def log_request_metrics(request, status)
    # Log request metrics for monitoring and analysis
    return unless Rails.env.production?
    
    Rails.logger.info(
      "[RateLimiter] " \
      "IP: #{request.ip}, " \
      "Method: #{request.request_method}, " \
      "Path: #{request.path}, " \
      "Status: #{status}, " \
      "User-Agent: #{request.user_agent&.truncate(100)}"
    )
  end
end
