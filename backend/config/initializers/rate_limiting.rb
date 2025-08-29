# Rate Limiting Configuration using Rack::Attack
# Implements multi-tiered rate limiting for API protection

class Rack::Attack
  # Configure Redis for rate limiting storage
  self.cache.store = ActiveSupport::Cache::RedisCacheStore.new(
    host: ENV.fetch('REDIS_HOST', 'localhost'),
    port: ENV.fetch('REDIS_PORT', 6379),
    db: ENV.fetch('REDIS_RATE_LIMIT_DB', 1),
    namespace: 'rate_limit'
  )

  # Enable/disable rate limiting via environment variable
  if ENV.fetch('RATE_LIMITING_ENABLED', 'true') == 'true'
    Rails.logger.info "[Rack::Attack] Rate limiting is enabled"

  # 1. GLOBAL PROTECTION: Emergency system-wide rate limiting
  throttle('global_requests', limit: 10000, period: 1.hour) do |req|
    req.ip if req.path.start_with?('/api/')
  end

  # 2. PER-IP RATE LIMITING: Prevent IP-based abuse
  throttle('requests_per_ip', limit: 300, period: 1.hour) do |req|
    req.ip if req.path.start_with?('/api/')
  end

  # More aggressive per-IP rate limiting for shorter periods
  throttle('requests_per_ip_short', limit: 60, period: 5.minutes) do |req|
    req.ip if req.path.start_with?('/api/')
  end

  # 3. PER-USER RATE LIMITING: Authenticated user limits
  throttle('authenticated_user_requests', limit: 1000, period: 1.hour) do |req|
    next unless req.path.start_with?('/api/') && req.env['HTTP_AUTHORIZATION']
    
    begin
      token = req.env['HTTP_AUTHORIZATION']&.split(' ')&.last
      if token
        decoded_token = JWT.decode(token, Rails.application.secret_key_base, true, algorithm: 'HS256')
        user_id = decoded_token[0]['user_id']
        "user:#{user_id}"
      end
    rescue JWT::DecodeError, JWT::ExpiredSignature
      nil
    end
  end

  # 4. ENDPOINT-SPECIFIC RATE LIMITING: Resource-intensive operations
  
  # Load creation and matching - high resource usage
  throttle('load_operations', limit: 100, period: 1.hour) do |req|
    req.ip if req.path.match(%r{^/api/v1/(loads|matching)}) && req.post?
  end

  # Load search - can be database intensive
  throttle('load_search', limit: 200, period: 1.hour) do |req|
    req.ip if req.path.match(%r{^/api/v1/loads/search}) && req.get?
  end

  # Route calculations - external API calls
  throttle('route_calculations', limit: 150, period: 1.hour) do |req|
    req.ip if req.path.match(%r{^/api/v1/routes})
  end

  # User authentication endpoints
  throttle('auth_requests', limit: 20, period: 1.hour) do |req|
    req.ip if req.path.match(%r{^/api/v1/auth/(login|register|password)})
  end

  # 5. BURST PROTECTION: Short-term spike protection
  throttle('burst_protection', limit: 30, period: 1.minute) do |req|
    req.ip if req.path.start_with?('/api/')
  end

  # 6. USER TIER-BASED LIMITS: Different limits based on user subscription
  throttle('premium_user_requests', limit: 2000, period: 1.hour) do |req|
    next unless req.path.start_with?('/api/') && req.env['HTTP_AUTHORIZATION']
    
    begin
      token = req.env['HTTP_AUTHORIZATION']&.split(' ')&.last
      if token
        decoded_token = JWT.decode(token, Rails.application.secret_key_base, true, algorithm: 'HS256')
        user_id = decoded_token[0]['user_id']
        user = User.find(user_id)
        
        # Only apply premium limits if user has premium subscription
        "premium_user:#{user_id}" if user&.subscription_tier == 'premium'
      end
    rescue JWT::DecodeError, JWT::ExpiredSignature, ActiveRecord::RecordNotFound
      nil
    end
  end

  # SAFELIST: Allow certain IPs to bypass rate limiting
  safelist('admin_ips') do |req|
    admin_ips = ENV.fetch('ADMIN_IPS', '').split(',').map(&:strip)
    admin_ips.include?(req.ip)
  end

  # Allow health check endpoints to bypass rate limiting
  safelist('health_checks') do |req|
    req.path.match(%r{^/(health|ping|status)})
  end

  # BLOCKLIST: Block known bad actors
  blocklist('bad_actors') do |req|
    blocked_ips = ENV.fetch('BLOCKED_IPS', '').split(',').map(&:strip)
    blocked_ips.include?(req.ip)
  end

  # LOGGING AND MONITORING
  ActiveSupport::Notifications.subscribe('throttle.rack_attack') do |name, start, finish, request_id, payload|
    req = payload[:request]
    Rails.logger.warn "[Rack::Attack] Rate limit exceeded: #{payload[:matched]} for IP: #{req.ip}, Path: #{req.path}"
    
    # You can add additional monitoring here (e.g., send to monitoring service)
    # Example: StatsD.increment('rate_limit.exceeded', tags: ["path:#{req.path}", "ip:#{req.ip}"])
  end

  ActiveSupport::Notifications.subscribe('blacklist.rack_attack') do |name, start, finish, request_id, payload|
    req = payload[:request]
    Rails.logger.error "[Rack::Attack] Blocked request from IP: #{req.ip}, Path: #{req.path}"
  end

  # Custom response for rate limited requests
  self.throttled_response = lambda do |env|
    match_data = env['rack.attack.match_data']
    now = Time.now
    retry_after = match_data[:period] - (now.to_i % match_data[:period])

    [
      429, # Too Many Requests
      {
        'Content-Type' => 'application/json',
        'Retry-After' => retry_after.to_s,
        'X-RateLimit-Limit' => match_data[:limit].to_s,
        'X-RateLimit-Remaining' => '0',
        'X-RateLimit-Reset' => (now + retry_after).to_i.to_s
      },
      [{
        error: 'Rate limit exceeded',
        message: 'Too many requests. Please try again later.',
        retry_after: retry_after,
        limit: match_data[:limit],
        period: match_data[:period]
      }.to_json]
    ]
  end

  # Custom response for blocked requests
  self.blocklisted_response = lambda do |env|
    [
      403, # Forbidden
      { 'Content-Type' => 'application/json' },
      [{ error: 'Forbidden', message: 'Your request has been blocked.' }.to_json]
    ]
  end

  Rails.logger.info "[Rack::Attack] Rate limiting initialized with Redis store"
  else
    Rails.logger.info "[Rack::Attack] Rate limiting is disabled"
  end
end