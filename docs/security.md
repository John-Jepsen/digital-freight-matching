# Security Guide

Comprehensive security implementation and best practices for the Digital Freight Matching Platform.

## 🔐 Security Overview

The platform implements multiple layers of security including authentication, authorization, data protection, and infrastructure security. This guide covers implemented security measures and operational best practices.

## 🛡️ Authentication & Authorization

### JWT Token Authentication
**Implementation**: Stateless JWT tokens for API authentication

**Features**:
- Secure token generation with HS256 algorithm
- Configurable token expiration (default: 24 hours)
- Automatic token refresh capability
- Secure logout with token invalidation

**Usage**:
```bash
# Login to get token
curl -X POST http://localhost:3001/api/v1/users/login \
  -H "Content-Type: application/json" \
  -d '{"email":"user@example.com","password":"password"}'

# Use token in subsequent requests
curl -H "Authorization: Bearer <token>" \
  http://localhost:3001/api/v1/users/profile
```

### Role-Based Access Control (RBAC)
**User Types**:
- **Shipper**: Can post loads, view carriers, manage shipments
- **Carrier**: Can search loads, accept jobs, update locations
- **Admin**: Full system access, user management, analytics

**Controller-Level Authorization**:
```ruby
before_action :require_shipper!, only: [:create_load]
before_action :require_carrier!, only: [:accept_load]
before_action :require_admin!, only: [:user_management]
```

## 🗄️ Database Security

### Row-Level Security (RLS)
**Implemented Policies**:

**Users Table**:
- Users can only access their own profile data
- Admins have full access to all user records
- Automatic enforcement at PostgreSQL level

**Payments Table**:
- Users can only see payments they're involved in
- Prevents unauthorized financial data access

**Audit Logs**:
- Admin-only access to system audit trails
- Complete activity tracking for compliance

### Data Validation & Protection
**JSONB Field Validation**:
```sql
-- Ratings validation
CHECK (
  ratings_data @> '{"categories": []}' AND
  jsonb_array_length(ratings_data->'categories') BETWEEN 1 AND 10
)

-- Route data validation  
CHECK (
  route_data ? 'distance' AND
  route_data ? 'duration' AND
  (route_data->>'distance')::numeric > 0
)
```

**Input Sanitization**:
- ActiveRecord ORM prevents SQL injection
- Strong parameter filtering in controllers
- Comprehensive model validations

## 🔧 Environment Security

### Secure Configuration Management
**Environment Variables**: All sensitive data externalized

```bash
# Database credentials
POSTGRES_PASSWORD=secure_password_here
POSTGRES_USER=freight_user

# Redis authentication
REDIS_PASSWORD=redis_secure_password

# JWT secret key
JWT_SECRET_KEY=your_secure_jwt_secret

# Google Maps API
GOOGLE_MAPS_API_KEY=your_api_key_here

# Grafana admin password
GRAFANA_ADMIN_PASSWORD=grafana_secure_password
```

### Secrets Management
**Rails Credentials** (Recommended for production):
```bash
# Edit encrypted credentials
rails credentials:edit

# Add sensitive data:
# google_maps_api_key: your_actual_api_key
# database_password: production_db_password
# jwt_secret: production_jwt_secret
```

### Docker Security
**No Hardcoded Secrets**:
```yaml
# docker-compose.yml - secure configuration
environment:
  POSTGRES_PASSWORD: ${POSTGRES_PASSWORD:-freight_pass_changeme}
  REDIS_PASSWORD: ${REDIS_PASSWORD:-redis_pass_changeme}
```

**Default Security Warnings**:
- All default passwords include `_changeme` suffix
- Clear indication in logs when defaults are used
- Documentation mandates changing defaults

## 🌐 Network Security

### CORS Configuration
**Specific Origin Control**:
```ruby
Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins 'http://localhost:3000', 'http://localhost:3002'
    resource '*',
      headers: :any,
      methods: [:get, :post, :put, :patch, :delete, :options, :head],
      credentials: true
  end
end
```

### HTTPS Enforcement (Production)
```ruby
# config/environments/production.rb
config.force_ssl = true
config.ssl_options = {
  redirect: { exclude: ->(request) { request.path =~ /health/ } }
}
```

### API Rate Limiting
**Implemented Limits**:
- Authentication endpoints: 5 requests/minute
- Search endpoints: 60 requests/minute  
- General API: 100 requests/minute
- Automatic IP-based blocking for abuse

## 📊 Audit & Monitoring

### Security Audit Log
**Tracked Events**:
- User authentication attempts (success/failure)
- Authorization failures
- Data modification operations
- Admin actions and privilege escalations
- API rate limit violations

**Log Format**:
```json
{
  "timestamp": "2025-07-31T12:00:00Z",
  "event_type": "authentication_failure",
  "user_id": null,
  "ip_address": "192.168.1.100",
  "details": {
    "email": "attempted_email@example.com",
    "reason": "invalid_password"
  }
}
```

### Real-time Security Monitoring
**Alerts for**:
- Multiple failed login attempts
- Suspicious API usage patterns
- Unauthorized access attempts
- Database connection anomalies

## 🔍 Security Verification

### Automated Security Checks
**Development Commands**:
```bash
# Check for hardcoded secrets
grep -r "changeme" docker-compose.yml
# Should show fallback passwords only

# Verify environment variable usage
grep -E "POSTGRES_PASSWORD|REDIS_PASSWORD" docker-compose.yml
# Should show ${VAR:-default} format

# Test database security
docker compose exec postgres psql -U freight_user -d freight_matching \
  -c "SELECT current_setting('row_security');"
# Should return 'on'
```

### Security Testing Checklist
- [ ] No hardcoded credentials in source code
- [ ] All environment variables properly configured
- [ ] JWT tokens expire and refresh correctly
- [ ] Row-level security policies enforce access control
- [ ] CORS allows only specified origins
- [ ] API rate limiting blocks excessive requests
- [ ] HTTPS enforced in production environment
- [ ] Database connections encrypted
- [ ] Audit logging captures security events

## 🚨 Incident Response

### Security Breach Protocol
1. **Immediate Response**:
   - Rotate all credentials immediately
   - Block suspicious IP addresses
   - Review audit logs for extent of breach
   - Notify affected users

2. **Investigation**:
   - Analyze attack vectors
   - Review system logs and database audit trails
   - Assess data exposure scope
   - Document findings

3. **Recovery**:
   - Patch security vulnerabilities
   - Update security configurations
   - Enhance monitoring and alerting
   - Conduct post-incident review

### Emergency Contacts
```bash
# Disable user account immediately
rails console
User.find_by(email: 'suspicious@email.com').update!(active: false)

# Block IP address (implement in load balancer/WAF)
# Review recent activity
AuditLog.where(ip_address: 'suspicious_ip').recent
```

## 🔒 Best Practices

### Development Security
- Never commit secrets to version control
- Use `.env.template` for environment setup
- Regularly update dependencies for security patches
- Implement security linting in CI/CD pipeline
- Use strong, unique passwords for all services

### Production Security
- Implement Web Application Firewall (WAF)
- Regular security audits and penetration testing
- Database encryption at rest and in transit
- Regular backup testing and recovery procedures
- Monitor and alert on all security events

### User Security
- Enforce strong password requirements
- Implement multi-factor authentication (planned)
- Regular password reset reminders
- Security awareness training for users
- Clear privacy policy and data handling

## 📋 Compliance Considerations

### Data Protection
- GDPR compliance for European users
- CCPA compliance for California users
- Industry-specific freight regulations
- Financial data handling requirements

### Audit Requirements
- Complete activity logging
- Data retention policies
- Regular compliance reviews
- Third-party security assessments

---

**Security Contact**: Create a security issue in the repository for security-related concerns.  
**Last Security Review**: July 31, 2025  
**Next Scheduled Review**: October 31, 2025  

*Security is an ongoing process. Regularly review and update security measures.*
