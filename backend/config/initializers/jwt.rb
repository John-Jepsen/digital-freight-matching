# JWT Configuration
Rails.application.configure do
  # JWT secret key - in production, this should be stored in environment variables
  config.jwt_secret = ENV.fetch('JWT_SECRET') { Rails.application.secrets.secret_key_base }
  
  # JWT expiration time (24 hours by default)
  config.jwt_expiration = ENV.fetch('JWT_EXPIRATION') { 24.hours.to_i }
end