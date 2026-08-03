# Security Implementation & Best Practices

## Security Architecture Overview

The Digital Freight Matching Platform implements comprehensive security measures across authentication, authorization, data protection, and operational security to protect sensitive freight and business data.

### Security Layers
1. **Application Security**: Authentication, authorization, input validation
2. **Data Security**: Encryption, Row-Level Security (RLS), audit logging
3. **Network Security**: HTTPS, CORS, rate limiting
4. **Infrastructure Security**: Environment isolation, secrets management

## Authentication System

### JWT Token Management
```ruby
class AuthenticationService
  SECRET_KEY = Rails.application.credentials.jwt_secret_key
  ALGORITHM = 'HS256'
  TOKEN_LIFETIME = 24.hours

  def self.encode_token(payload)
    payload[:iat] = Time.current.to_i
    payload[:exp] = TOKEN_LIFETIME.from_now.to_i
    payload[:jti] = SecureRandom.uuid  # JWT ID for revocation
    
    JWT.encode(payload, SECRET_KEY, ALGORITHM)
  end

  def self.decode_token(token)
    decoded = JWT.decode(token, SECRET_KEY, true, { algorithm: ALGORITHM }).first
    
    # Check if token is blacklisted
    return nil if TokenBlacklist.exists?(jti: decoded['jti'])
    
    decoded
  rescue JWT::DecodeError, JWT::ExpiredSignature => e
    Rails.logger.warn "JWT decode error: #{e.message}"
    nil
  end

  def self.revoke_token(token)
    decoded = JWT.decode(token, SECRET_KEY, false).first
    TokenBlacklist.create!(
      jti: decoded['jti'],
      expires_at: Time.at(decoded['exp'])
    )
  end
end

# Token blacklist for revocation
class TokenBlacklist < ApplicationRecord
  validates :jti, presence: true, uniqueness: true
  
  scope :expired, -> { where('expires_at < ?', Time.current) }
  
  # Clean up expired tokens daily
  def self.cleanup_expired
    expired.delete_all
  end
end
```

### Secure Authentication Controller
```ruby
class ApplicationController < ActionController::API
  before_action :authenticate_user!
  
  private
  
  def authenticate_user!
    token = extract_token_from_header
    
    if token.present?
      decoded_token = AuthenticationService.decode_token(token)
      
      if decoded_token
        @current_user = User.find_by(id: decoded_token['user_id'])
        set_current_user_context if @current_user
      end
    end
    
    render json: { error: 'Unauthorized access' }, status: :unauthorized unless @current_user
  end
  
  def extract_token_from_header
    auth_header = request.headers['Authorization']
    auth_header.split(' ').last if auth_header&.start_with?('Bearer ')
  end
  
  def set_current_user_context
    # Set context for Row-Level Security
    ActiveRecord::Base.connection.execute(
      "SET app.current_user_id = #{@current_user.id}"
    )
    ActiveRecord::Base.connection.execute(
      "SET app.current_user_role = '#{@current_user.user_type}'"
    )
    
    # Set shipper/carrier context
    if @current_user.shipper_profile
      ActiveRecord::Base.connection.execute(
        "SET app.current_shipper_id = #{@current_user.shipper_profile.id}"
      )
    elsif @current_user.carrier_profile
      ActiveRecord::Base.connection.execute(
        "SET app.current_carrier_id = #{@current_user.carrier_profile.id}"
      )
    end
  end
  
  def current_user
    @current_user
  end
end
```

### Password Security
```ruby
class User < ApplicationRecord
  has_secure_password
  
  validates :password, length: { minimum: 12 }, 
                      format: { 
                        with: /\A(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]/,
                        message: "must contain uppercase, lowercase, number, and special character"
                      }
  
  # Account lockout after failed attempts
  validates :failed_attempts, presence: true, numericality: { greater_than_or_equal_to: 0 }
  
  MAX_FAILED_ATTEMPTS = 5
  LOCKOUT_DURATION = 30.minutes
  
  def increment_failed_attempts!
    increment!(:failed_attempts)
    
    if failed_attempts >= MAX_FAILED_ATTEMPTS
      update!(locked_until: LOCKOUT_DURATION.from_now)
    end
  end
  
  def reset_failed_attempts!
    update!(failed_attempts: 0, locked_until: nil) if failed_attempts > 0
  end
  
  def account_locked?
    locked_until.present? && locked_until > Time.current
  end
  
  def authenticate(password)
    return false if account_locked?
    
    if super(password)
      reset_failed_attempts!
      true
    else
      increment_failed_attempts!
      false
    end
  end
end
```

## Authorization with Pundit

### Policy-Based Access Control
```ruby
# Base policy for common authorization patterns
class ApplicationPolicy
  attr_reader :user, :record

  def initialize(user, record)
    @user = user
    @record = record
  end

  def index?
    false
  end

  def show?
    false
  end

  def create?
    false
  end

  def new?
    create?
  end

  def update?
    false
  end

  def edit?
    update?
  end

  def destroy?
    false
  end

  class Scope
    def initialize(user, scope)
      @user = user
      @scope = scope
    end

    def resolve
      raise NotImplementedError
    end

    private

    attr_reader :user, :scope
  end

  private

  def admin?
    user.admin?
  end

  def shipper?
    user.shipper?
  end

  def carrier?
    user.carrier?
  end

  def owns_record?
    record.respond_to?(:user) && record.user == user
  end
end

# Load-specific authorization
class LoadPolicy < ApplicationPolicy
  def index?
    true  # Users can see loads based on RLS
  end

  def show?
    admin? || owns_load? || carrier_can_view?
  end

  def create?
    shipper?
  end

  def update?
    admin? || (shipper? && owns_load? && load_editable?)
  end

  def destroy?
    admin? || (shipper? && owns_load? && record.posted?)
  end

  def book?
    carrier? && record.posted? && !already_matched?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      case user.user_type
      when 'admin'
        scope.all
      when 'shipper'
        scope.joins(:shipper).where(shipper_profiles: { user_id: user.id })
      when 'carrier'
        # Carriers see posted loads or loads they've matched
        scope.where(status: 'posted')
             .or(scope.joins(:matches).where(matches: { carrier_id: user.carrier_profile&.id }))
      else
        scope.none
      end
    end
  end

  private

  def owns_load?
    record.shipper.user == user
  end

  def carrier_can_view?
    carrier? && (record.posted? || user.carrier_profile&.matches&.exists?(load: record))
  end

  def load_editable?
    %w[posted matched].include?(record.status)
  end

  def already_matched?
    record.matches.exists?(carrier: user.carrier_profile)
  end
end

# Match-specific authorization
class MatchPolicy < ApplicationPolicy
  def show?
    admin? || shipper_owns_load? || carrier_owns_match?
  end

  def accept?
    carrier_owns_match? && record.pending?
  end

  def reject?
    carrier_owns_match? && record.pending?
  end

  def cancel?
    shipper_owns_load? && record.can_be_cancelled?
  end

  private

  def shipper_owns_load?
    shipper? && record.load.shipper.user == user
  end

  def carrier_owns_match?
    carrier? && record.carrier.user == user
  end
end
```

### Secure Controller Implementation
```ruby
class Api::V1::LoadsController < ApplicationController
  include Pundit::Authorization
  
  before_action :set_load, only: [:show, :update, :destroy, :book]
  after_action :verify_authorized, except: [:index, :search]
  after_action :verify_policy_scoped, only: [:index, :search]
  
  def index
    @loads = policy_scope(Load).includes(:shipper, :load_requirements, :matches)
                               .page(params[:page])
                               .per(params[:per_page] || 10)
    
    render json: {
      data: LoadSerializer.new(@loads),
      pagination: pagination_meta(@loads)
    }
  end
  
  def show
    authorize @load
    render json: { data: LoadSerializer.new(@load) }
  end
  
  def create
    authorize Load
    
    @load = current_user.shipper_profile.loads.build(load_params)
    
    if @load.save
      AuditLog.create!(
        user: current_user,
        action: 'create_load',
        resource: @load,
        details: { load_id: @load.id }
      )
      
      render json: { data: LoadSerializer.new(@load) }, status: :created
    else
      render json: { errors: @load.errors }, status: :unprocessable_entity
    end
  end
  
  def book
    authorize @load, :book?
    
    service = LoadBookingService.new(@load, current_user.carrier_profile)
    result = service.call
    
    if result.success?
      AuditLog.create!(
        user: current_user,
        action: 'book_load',
        resource: @load,
        details: { match_id: result.data.id }
      )
      
      render json: { data: MatchSerializer.new(result.data) }
    else
      render json: { error: result.error }, status: :unprocessable_entity
    end
  end
  
  private
  
  def set_load
    @load = Load.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Load not found' }, status: :not_found
  end
end
```

## Data Protection

### Row-Level Security (RLS) Implementation
```sql
-- Enable RLS on all sensitive tables
ALTER TABLE loads ENABLE ROW LEVEL SECURITY;
ALTER TABLE matches ENABLE ROW LEVEL SECURITY;
ALTER TABLE shipments ENABLE ROW LEVEL SECURITY;
ALTER TABLE tracking_events ENABLE ROW LEVEL SECURITY;

-- Comprehensive load access policy
CREATE POLICY comprehensive_loads_policy ON loads
  FOR ALL TO authenticated_user
  USING (
    -- Shippers see their own loads
    (current_setting('app.current_user_role') = 'shipper' 
     AND shipper_id::text = current_setting('app.current_shipper_id'))
    OR
    -- Carriers see posted loads or loads they have matches for
    (current_setting('app.current_user_role') = 'carrier' 
     AND (status = 'posted' 
          OR id IN (
            SELECT load_id FROM matches 
            WHERE carrier_id::text = current_setting('app.current_carrier_id')
          )))
    OR
    -- Admins see everything
    current_setting('app.current_user_role') = 'admin'
  )
  WITH CHECK (
    -- Only shippers can create/update their loads
    current_setting('app.current_user_role') = 'shipper' 
    AND shipper_id::text = current_setting('app.current_shipper_id')
  );

-- Tracking events security
CREATE POLICY tracking_events_policy ON tracking_events
  FOR ALL TO authenticated_user
  USING (
    -- Users can only see tracking for shipments they're involved with
    shipment_id IN (
      SELECT s.id FROM shipments s
      JOIN matches m ON s.match_id = m.id
      JOIN loads l ON m.load_id = l.id
      WHERE 
        (current_setting('app.current_user_role') = 'shipper' 
         AND l.shipper_id::text = current_setting('app.current_shipper_id'))
        OR
        (current_setting('app.current_user_role') = 'carrier' 
         AND m.carrier_id::text = current_setting('app.current_carrier_id'))
        OR
        current_setting('app.current_user_role') = 'admin'
    )
  );
```

### Sensitive Data Encryption
```ruby
# Encrypt sensitive data at application level
class CarrierProfile < ApplicationRecord
  encrypts :insurance_info
  encrypts :bank_account_number, deterministic: true  # For lookups
  
  # Blind indexing for encrypted search
  blind_index :insurance_policy_number, key: :insurance_key
  
  validates :dot_number, presence: true, uniqueness: true
  validates :mc_number, presence: true, uniqueness: true
  
  # Sensitive data access logging
  def insurance_info
    AuditLog.create!(
      user: Current.user,
      action: 'access_sensitive_data',
      resource: self,
      details: { field: 'insurance_info' }
    )
    
    super
  end
end

# Personal Identifiable Information protection
class Driver < ApplicationRecord
  encrypts :license_number, deterministic: true
  encrypts :ssn
  
  # Data retention compliance
  scope :eligible_for_purge, -> { 
    where('updated_at < ?', 7.years.ago)
      .where(status: 'inactive') 
  }
  
  def purge_personal_data!
    update!(
      first_name: '[REDACTED]',
      last_name: '[REDACTED]',
      phone_number: nil,
      email: nil,
      ssn: nil,
      status: 'purged'
    )
  end
end
```

## Security Monitoring & Audit Logging

### Comprehensive Audit System
```ruby
class AuditLog < ApplicationRecord
  belongs_to :user, optional: true
  
  validates :action, presence: true
  validates :details, presence: true
  
  scope :security_events, -> { where(action: SECURITY_ACTIONS) }
  scope :recent, -> { where('created_at > ?', 30.days.ago) }
  
  SECURITY_ACTIONS = %w[
    login_attempt
    login_success
    login_failure
    password_change
    account_locked
    token_refresh
    unauthorized_access
    sensitive_data_access
    admin_privilege_use
  ].freeze
  
  # Automatically create audit logs for sensitive operations
  def self.log_security_event(user, action, details = {})
    create!(
      user: user,
      action: action,
      ip_address: details[:ip_address],
      user_agent: details[:user_agent],
      details: details.except(:ip_address, :user_agent),
      created_at: Time.current
    )
  end
  
  # Security alert thresholds
  def self.check_security_alerts
    # Multiple failed login attempts
    failed_logins = where(action: 'login_failure')
                   .where('created_at > ?', 1.hour.ago)
                   .group(:ip_address)
                   .having('COUNT(*) > ?', 10)
    
    failed_logins.each do |log|
      SecurityAlert.create!(
        alert_type: 'multiple_failed_logins',
        severity: 'high',
        details: { ip_address: log.ip_address, attempts: log.count }
      )
    end
  end
end

# Security monitoring service
class SecurityMonitoringService
  def self.monitor_request(request, user, controller, action)
    suspicious_patterns = [
      { pattern: /\b(SELECT|INSERT|UPDATE|DELETE|DROP)\b/i, type: 'sql_injection' },
      { pattern: /<script|javascript:|on\w+=/i, type: 'xss_attempt' },
      { pattern: /\.\.|\/etc\/|\/proc\//i, type: 'path_traversal' }
    ]
    
    # Check for suspicious patterns in parameters
    request.params.each do |key, value|
      next unless value.is_a?(String)
      
      suspicious_patterns.each do |pattern_info|
        if value.match?(pattern_info[:pattern])
          AuditLog.log_security_event(
            user,
            'suspicious_request',
            {
              pattern_type: pattern_info[:type],
              parameter: key,
              value: value.truncate(100),
              controller: controller,
              action: action,
              ip_address: request.remote_ip,
              user_agent: request.user_agent
            }
          )
          
          # Block request if pattern is high-risk
          return false if high_risk_pattern?(pattern_info[:type])
        end
      end
    end
    
    true
  end
  
  private
  
  def self.high_risk_pattern?(type)
    %w[sql_injection path_traversal].include?(type)
  end
end
```

### Rate Limiting & DDoS Protection
```ruby
class RateLimitMiddleware
  LIMITS = {
    '/api/v1/auth/login' => { requests: 5, period: 15.minutes },
    '/api/v1/auth/register' => { requests: 3, period: 1.hour },
    '/api/v1/loads/search' => { requests: 60, period: 1.minute },
    default: { requests: 100, period: 1.minute }
  }.freeze
  
  def initialize(app)
    @app = app
  end
  
  def call(env)
    request = ActionDispatch::Request.new(env)
    
    if rate_limit_exceeded?(request)
      return rate_limit_response
    end
    
    @app.call(env)
  end
  
  private
  
  def rate_limit_exceeded?(request)
    key = rate_limit_key(request)
    limit_config = LIMITS[request.path] || LIMITS[:default]
    
    current_count = Rails.cache.read(key) || 0
    
    if current_count >= limit_config[:requests]
      # Log potential DDoS attempt
      AuditLog.log_security_event(
        nil,
        'rate_limit_exceeded',
        {
          ip_address: request.remote_ip,
          path: request.path,
          current_count: current_count,
          limit: limit_config[:requests]
        }
      )
      
      return true
    end
    
    Rails.cache.write(
      key, 
      current_count + 1, 
      expires_in: limit_config[:period]
    )
    
    false
  end
  
  def rate_limit_key(request)
    "rate_limit:#{request.remote_ip}:#{request.path}"
  end
  
  def rate_limit_response
    [
      429,
      {
        'Content-Type' => 'application/json',
        'Retry-After' => '900'  # 15 minutes
      },
      [{ error: 'Rate limit exceeded' }.to_json]
    ]
  end
end
```

## Input Validation & Sanitization

### Strong Parameter Validation
```ruby
class Api::V1::LoadsController < ApplicationController
  private
  
  def load_params
    params.require(:load).permit(
      :pickup_location, :delivery_location, :pickup_datetime, :delivery_datetime,
      :weight, :price, :description,
      load_requirements_attributes: [
        :equipment_type, :hazmat, :temperature_controlled, :special_handling
      ],
      cargo_details_attributes: [
        :freight_class, :pieces, :packaging, :value,
        dimensions: [:length, :width, :height]
      ]
    )
  end
  
  # Additional parameter sanitization
  def sanitized_params
    params = load_params
    
    # Strip HTML tags from text fields
    params[:description] = ActionController::Base.helpers.strip_tags(params[:description]) if params[:description]
    
    # Validate geographic coordinates if provided
    if params[:pickup_lat] && params[:pickup_lng]
      unless valid_coordinates?(params[:pickup_lat], params[:pickup_lng])
        raise ActionController::BadRequest, "Invalid pickup coordinates"
      end
    end
    
    # Ensure price is reasonable
    if params[:price] && (params[:price] < 50 || params[:price] > 50_000)
      raise ActionController::BadRequest, "Price must be between $50 and $50,000"
    end
    
    params
  end
  
  def valid_coordinates?(lat, lng)
    lat.to_f.between?(-90, 90) && lng.to_f.between?(-180, 180)
  end
end
```

### SQL Injection Prevention
```ruby
# Always use parameterized queries
class LoadSearchService
  def initialize(params, user)
    @params = params
    @user = user
  end
  
  def call
    query = Load.joins(:shipper_profile, :load_requirements)
    
    # Safe parameter binding
    query = query.where("pickup_location ILIKE ?", "%#{sanitize_search_term(@params[:location])}%") if @params[:location]
    query = query.where("price BETWEEN ? AND ?", @params[:min_price], @params[:max_price]) if price_range_valid?
    query = query.where("pickup_datetime >= ?", @params[:pickup_date]) if @params[:pickup_date]
    
    # Use Arel for complex queries
    query = query.where(
      Load.arel_table[:distance_miles].lteq(@params[:max_distance])
    ) if @params[:max_distance]
    
    query.limit(100)  # Always limit results
  end
  
  private
  
  def sanitize_search_term(term)
    # Remove potentially dangerous characters
    term.to_s.gsub(/[<>&"']/, '')
           .strip
           .truncate(100)
  end
  
  def price_range_valid?
    @params[:min_price].present? && 
    @params[:max_price].present? && 
    @params[:min_price].to_f > 0 && 
    @params[:max_price].to_f > @params[:min_price].to_f
  end
end
```

## Network Security

### CORS Configuration
```ruby
# config/initializers/cors.rb
Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins ENV['CORS_ALLOWED_ORIGINS']&.split(',') || ['http://localhost:3000', 'http://localhost:3002']
    
    resource '/api/v1/*',
      headers: :any,
      methods: [:get, :post, :put, :patch, :delete, :options, :head],
      credentials: true,
      max_age: 86400  # 24 hours
  end
  
  # Health check endpoint - no credentials
  allow do
    origins '*'
    resource '/health',
      headers: :any,
      methods: [:get, :head],
      credentials: false
  end
end
```

### HTTPS Enforcement
```ruby
# config/environments/production.rb
Rails.application.configure do
  # Force all access to the app over SSL
  config.force_ssl = true
  
  # Use secure cookies
  config.session_store :cookie_store, 
    key: '_digital_freight_session',
    secure: true,
    httponly: true,
    same_site: :strict
end

# Security headers middleware
class SecurityHeadersMiddleware
  def initialize(app)
    @app = app
  end
  
  def call(env)
    status, headers, response = @app.call(env)
    
    # Add security headers
    headers.merge!(
      'X-Frame-Options' => 'DENY',
      'X-Content-Type-Options' => 'nosniff',
      'X-XSS-Protection' => '1; mode=block',
      'Strict-Transport-Security' => 'max-age=31536000; includeSubDomains',
      'Content-Security-Policy' => csp_header,
      'Referrer-Policy' => 'strict-origin-when-cross-origin'
    )
    
    [status, headers, response]
  end
  
  private
  
  def csp_header
    "default-src 'self'; " \
    "script-src 'self' 'unsafe-inline'; " \
    "style-src 'self' 'unsafe-inline'; " \
    "img-src 'self' data: https:; " \
    "connect-src 'self' https://maps.googleapis.com; " \
    "frame-ancestors 'none'"
  end
end
```

*This comprehensive security implementation ensures the freight matching platform maintains the highest standards of data protection and operational security.*
