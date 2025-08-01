# Configuration Guide

External services, environment setup, and configuration management for the Digital Freight Matching Platform.

## 🌐 External Service Integration

### Google Maps API Setup

The platform integrates with Google Maps for advanced route optimization and location services.

#### API Key Configuration

**Option 1: Rails Credentials (Recommended for Production)**
```bash
# Edit encrypted credentials
cd backend
rails credentials:edit

# Add to the credentials file:
google_maps_api_key: your_actual_api_key_here
```

**Option 2: Environment Variable (Development)**
```bash
# Set environment variable
export GOOGLE_MAPS_API_KEY=your_actual_api_key_here

# Or add to .env file
echo "GOOGLE_MAPS_API_KEY=your_actual_api_key_here" >> .env
```

#### Required Google Cloud APIs

Enable these APIs in your [Google Cloud Console](https://console.cloud.google.com/):

1. **Directions API** - Route calculation and optimization
2. **Distance Matrix API** - Bulk distance calculations  
3. **Geocoding API** - Address to coordinates conversion
4. **Roads API** (Optional) - Enhanced route optimization

**API Usage Limits**:
- Development: 2,500 requests/day (free tier)
- Production: Set up billing for higher limits
- Caching: 2-hour cache reduces API calls

#### Cost Optimization
```ruby
# Route caching configuration (backend/app/services/route_calculation_service.rb)
def cache_key(origin, destination, options = {})
  "route:#{Digest::MD5.hexdigest([origin, destination, options].to_s)}"
end

def cached_route(origin, destination, options = {})
  Rails.cache.fetch(cache_key(origin, destination, options), expires_in: 2.hours) do
    calculate_route_with_google_maps(origin, destination, options)
  end
end
```

### Service Fallbacks

**Google Maps Unavailable**: The system automatically falls back to basic calculations:
```ruby
def google_maps_available?
  google_maps_api_key.present?
end

def calculate_distance(origin, destination)
  if google_maps_available?
    google_maps_distance(origin, destination)
  else
    haversine_distance(origin, destination)
  end
end
```

## 🔐 Environment Configuration

### Environment Variables Reference

#### Database Configuration
```bash
# PostgreSQL Database
POSTGRES_HOST=localhost
POSTGRES_PORT=5432
POSTGRES_DB=freight_matching
POSTGRES_USER=freight_user
POSTGRES_PASSWORD=your_secure_password

# Database URL (alternative format)
DATABASE_URL=postgresql://freight_user:password@localhost:5432/freight_matching
```

#### Cache & Session Storage
```bash
# Redis Configuration
REDIS_HOST=localhost
REDIS_PORT=6379
REDIS_PASSWORD=your_redis_password
REDIS_URL=redis://:password@localhost:6379/0

# Session configuration
SESSION_STORE=redis
SESSION_EXPIRE_TIME=86400  # 24 hours in seconds
```

#### Application Security
```bash
# JWT Authentication
JWT_SECRET_KEY=your_very_long_and_secure_jwt_secret_key
JWT_EXPIRATION_TIME=86400  # 24 hours

# Rails secret keys
SECRET_KEY_BASE=your_rails_secret_key_base
```

#### External Services
```bash
# Google Maps API
GOOGLE_MAPS_API_KEY=your_google_maps_api_key

# Email Service (optional)
SMTP_HOST=smtp.example.com
SMTP_PORT=587
SMTP_USERNAME=your_email@example.com
SMTP_PASSWORD=your_email_password

# File Storage (optional - for document uploads)
AWS_ACCESS_KEY_ID=your_aws_access_key
AWS_SECRET_ACCESS_KEY=your_aws_secret_key
AWS_S3_BUCKET=your_s3_bucket_name
AWS_REGION=us-east-1
```

#### Application Configuration
```bash
# Environment
RAILS_ENV=development  # development, test, production
NODE_ENV=development   # development, production

# Logging
LOG_LEVEL=debug        # debug, info, warn, error
LOG_TO_STDOUT=true     # true for containerized environments

# Performance
RAILS_MAX_THREADS=5
WEB_CONCURRENCY=2

# Feature Flags
ENABLE_GOOGLE_MAPS=true
ENABLE_BACKGROUND_JOBS=true
ENABLE_REAL_TIME_TRACKING=true
```

### Environment-Specific Configuration

#### Development (.env.development)
```bash
# Relaxed security for development
JWT_SECRET_KEY=development_jwt_secret_key_not_secure
POSTGRES_PASSWORD=development_password

# Development-specific features
ENABLE_DEBUG_LOGGING=true
ENABLE_QUERY_LOGGING=true
CACHE_CLASSES=false

# Development URLs
FRONTEND_URL=http://localhost:3000
ADMIN_URL=http://localhost:3002
API_URL=http://localhost:3001
```

#### Production (.env.production)
```bash
# Strong security for production
JWT_SECRET_KEY=$(openssl rand -base64 64)
POSTGRES_PASSWORD=$(openssl rand -base64 32)

# Production optimizations
RAILS_SERVE_STATIC_FILES=true
RAILS_LOG_TO_STDOUT=true
FORCE_SSL=true

# Production URLs
FRONTEND_URL=https://app.yourcompany.com
ADMIN_URL=https://admin.yourcompany.com
API_URL=https://api.yourcompany.com
```

## 🐳 Docker Configuration

### Development Docker Setup

**docker-compose.yml** (Development):
```yaml
version: '3.8'
services:
  postgres:
    image: postgres:16
    environment:
      POSTGRES_DB: ${POSTGRES_DB:-freight_matching}
      POSTGRES_USER: ${POSTGRES_USER:-freight_user}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD:-freight_pass_changeme}
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./init-db.sql:/docker-entrypoint-initdb.d/init-db.sql

  redis:
    image: redis:7
    command: redis-server --requirepass ${REDIS_PASSWORD:-redis_pass_changeme}
    ports:
      - "6379:6379"
    volumes:
      - redis_data:/data

volumes:
  postgres_data:
  redis_data:
```

**docker-compose.override.yml** (Development overrides):
```yaml
version: '3.8'
services:
  backend:
    build: ./backend
    ports:
      - "3001:3001"
    volumes:
      - ./backend:/app
      - bundle_cache:/usr/local/bundle
    environment:
      - RAILS_ENV=development
      - DATABASE_URL=postgresql://freight_user:${POSTGRES_PASSWORD}@postgres:5432/freight_matching
    depends_on:
      - postgres
      - redis

volumes:
  bundle_cache:
```

### Production Docker Configuration

**docker-compose.prod.yml**:
```yaml
version: '3.8'
services:
  postgres:
    image: postgres:16
    environment:
      POSTGRES_DB: ${POSTGRES_DB}
      POSTGRES_USER: ${POSTGRES_USER}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./backups:/backups
    restart: unless-stopped
    
  redis:
    image: redis:7
    command: redis-server --requirepass ${REDIS_PASSWORD} --appendonly yes
    volumes:
      - redis_data:/data
    restart: unless-stopped

  backend:
    build:
      context: ./backend
      dockerfile: Dockerfile.prod
    environment:
      RAILS_ENV: production
      SECRET_KEY_BASE: ${SECRET_KEY_BASE}
      DATABASE_URL: postgresql://${POSTGRES_USER}:${POSTGRES_PASSWORD}@postgres:5432/${POSTGRES_DB}
    depends_on:
      - postgres
      - redis
    restart: unless-stopped

  nginx:
    image: nginx:alpine
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf
      - ./ssl:/etc/nginx/ssl
    depends_on:
      - backend
    restart: unless-stopped
```

## 🔒 Security Configuration

### SSL/TLS Setup (Production)

**Generate SSL Certificates**:
```bash
# Using Let's Encrypt (recommended)
certbot --nginx -d api.yourcompany.com -d app.yourcompany.com

# Or self-signed for testing
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout ssl/private.key -out ssl/certificate.crt
```

**Nginx SSL Configuration**:
```nginx
server {
    listen 443 ssl;
    server_name api.yourcompany.com;
    
    ssl_certificate /etc/nginx/ssl/certificate.crt;
    ssl_certificate_key /etc/nginx/ssl/private.key;
    
    location / {
        proxy_pass http://backend:3001;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

### Firewall Configuration

**Basic UFW Setup** (Ubuntu):
```bash
# Enable firewall
ufw enable

# Allow SSH
ufw allow ssh

# Allow HTTP/HTTPS
ufw allow 80
ufw allow 443

# Allow PostgreSQL (internal only)
ufw allow from 172.16.0.0/12 to any port 5432

# Deny all other traffic
ufw default deny incoming
ufw default allow outgoing
```

## 📊 Monitoring Configuration

### Application Monitoring

**Health Check Endpoints**:
```ruby
# config/routes.rb
Rails.application.routes.draw do
  root 'health#index'
  
  namespace :api do
    namespace :v1 do
      get 'health', to: 'health#show'
      get 'health/detailed', to: 'health#detailed'
    end
  end
end
```

**Monitoring Services Integration**:
```bash
# New Relic (optional)
NEW_RELIC_LICENSE_KEY=your_new_relic_license_key
NEW_RELIC_APP_NAME="Digital Freight Matching"

# Sentry for error tracking (optional)
SENTRY_DSN=your_sentry_dsn

# DataDog (optional)
DATADOG_API_KEY=your_datadog_api_key
```

### Database Monitoring

**PostgreSQL Configuration** (`postgresql.conf`):
```ini
# Logging
log_statement = 'all'
log_duration = on
log_checkpoints = on
log_connections = on
log_disconnections = on

# Performance
shared_buffers = 256MB
effective_cache_size = 1GB
work_mem = 4MB
maintenance_work_mem = 64MB
```

**Database Backup Configuration**:
```bash
#!/bin/bash
# backup-db.sh
BACKUP_DIR="/backups"
DATE=$(date +%Y%m%d_%H%M%S)
FILENAME="freight_matching_$DATE.sql"

pg_dump -h postgres -U freight_user freight_matching > "$BACKUP_DIR/$FILENAME"
gzip "$BACKUP_DIR/$FILENAME"

# Keep only last 7 days of backups
find $BACKUP_DIR -name "freight_matching_*.sql.gz" -mtime +7 -delete
```

## 🔧 Configuration Management Tools

### Using dotenv (Development)

**Install dotenv**:
```bash
# Backend (Rails)
gem 'dotenv-rails', groups: [:development, :test]

# Frontend (if needed)
npm install dotenv
```

**Usage**:
```ruby
# config/application.rb
require 'dotenv/load' if Rails.env.development?
```

### Rails Credentials (Production)

**Setup**:
```bash
# Generate new credentials
rails credentials:edit

# For specific environments
rails credentials:edit --environment production
```

**Access in code**:
```ruby
# Access credentials
Rails.application.credentials.google_maps_api_key
Rails.application.credentials.database_password

# Environment-specific
Rails.application.credentials.production.secret_key_base
```

## 🔄 Configuration Validation

### Startup Checks

**Backend Validation**:
```ruby
# config/initializers/configuration_check.rb
Rails.application.configure do
  config.after_initialize do
    required_env_vars = %w[
      POSTGRES_PASSWORD
      JWT_SECRET_KEY
    ]
    
    missing_vars = required_env_vars.select { |var| ENV[var].blank? }
    
    if missing_vars.any?
      Rails.logger.error "Missing required environment variables: #{missing_vars.join(', ')}"
      # raise "Configuration error" in production
    end
  end
end
```

**Configuration Test Script**:
```bash
#!/bin/bash
# test-config.sh

echo "Testing configuration..."

# Test database connection
docker compose exec backend rails runner "ActiveRecord::Base.connection"
echo "✅ Database connection: OK"

# Test Redis connection  
docker compose exec backend rails runner "Rails.cache.write('test', 'value')"
echo "✅ Redis connection: OK"

# Test API key (if configured)
if [ ! -z "$GOOGLE_MAPS_API_KEY" ]; then
  echo "✅ Google Maps API key: Configured"
else
  echo "⚠️  Google Maps API key: Not configured (using fallback calculations)"
fi

echo "Configuration test complete!"
```

---

**Configuration Checklist**:
- [ ] Environment variables set for target environment
- [ ] Database connection tested
- [ ] Redis/cache connection verified  
- [ ] External API keys configured (if needed)
- [ ] SSL certificates in place (production)
- [ ] Monitoring and logging configured
- [ ] Backup procedures tested

*Need help with configuration? Check the [troubleshooting guide](./development.md#troubleshooting) or create an issue.*
