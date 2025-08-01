# Security Guidelines and Best Practices

## Overview
This document outlines security measures implemented to address findings from the security audit and establish best practices for the Digital Freight Matching platform.

## Audit Findings Addressed

### 1. Hardcoded Admin Credentials
**Issue**: Sample admin user with predictable credentials in `init-db.sql`
**Resolution**: 
- Removed hardcoded admin user creation from database initialization
- Added secure admin creation guidelines using Rails console
- Documented proper credential management practices

### 2. Database Password Security
**Issue**: Hardcoded database passwords in `docker-compose.yml`
**Resolution**:
- Converted all hardcoded passwords to environment variables
- Created `.env.template` with security guidelines
- Added default fallbacks with clear indication they must be changed

### 3. Grafana Admin Password
**Issue**: Default admin password exposed in configuration
**Resolution**:
- Converted to environment variable with secure fallback
- Added password strength recommendations

### 4. Port Security
**Issue**: Multiple services exposing ports without WAF protection
**Resolution**:
- Added security comments about WAF requirements
- Documented port monitoring best practices

### 5. Row-Level Security (RLS)
**Implementation**: Added comprehensive RLS policies for:
- Users table: Users can only access their own data, admins have full access
- Payments table: Users can only see payments they're involved in
- Audit logs: Admin-only access

### 6. JSONB Field Validation
**Implementation**: Added strict validation constraints for all JSONB fields:
- Ratings categories
- Route data
- Notification metadata
- Audit log values

## Security Implementation Details

### Row-Level Security Policies

```sql
-- Users can only see their own data, admins see all
CREATE POLICY users_own_data ON users 
  FOR ALL TO PUBLIC 
  USING (id = current_setting('app.current_user_id', true)::bigint OR 
         current_setting('app.current_user_type', true) = 'admin');

-- Payments restricted to participants
CREATE POLICY payments_participant_access ON payments 
  FOR ALL TO PUBLIC 
  USING (payer_id = current_setting('app.current_user_id', true)::bigint OR 
         payee_id = current_setting('app.current_user_id', true)::bigint OR
         current_setting('app.current_user_type', true) = 'admin');

-- Audit logs for admins only
CREATE POLICY audit_logs_admin_only ON audit_logs 
  FOR ALL TO PUBLIC 
  USING (current_setting('app.current_user_type', true) = 'admin');
```

### JSONB Validation Constraints

```sql
-- Ensure JSONB fields contain valid JSON objects
ALTER TABLE ratings ADD CONSTRAINT valid_categories_jsonb 
  CHECK (categories IS NULL OR jsonb_typeof(categories) = 'object');

ALTER TABLE routes ADD CONSTRAINT valid_route_data_jsonb 
  CHECK (route_data IS NULL OR jsonb_typeof(route_data) = 'object');

-- Additional constraints for all JSONB fields
```

## Recommended Security Practices

### 1. Credential Management
- **Never** commit credentials to version control
- Use environment variables for all sensitive configuration
- Implement secrets management services (AWS Secrets Manager, HashiCorp Vault) for production
- Rotate passwords regularly (quarterly minimum)
- Use strong, unique passwords (minimum 16 characters, mixed case, numbers, symbols)

### 2. Admin User Creation
Create admin users securely through Rails console:

```ruby
# In Rails console
admin = User.new(
  email: ENV['ADMIN_EMAIL'] || 'admin@yourdomain.com',
  password: SecureRandom.base64(32),
  first_name: 'System',
  last_name: 'Administrator', 
  user_type: 'admin',
  active: true,
  email_verified: true,
  confirmed_at: Time.current
)
admin.save!
puts "Admin created with email: #{admin.email}"
puts "Temporary password: #{admin.password}" # Save this securely
```

### 3. Application Security
- Enable row-level security context in Rails controllers:
  ```ruby
  before_action :set_rls_context
  
  private
  
  def set_rls_context
    ActiveRecord::Base.connection.execute(
      "SET app.current_user_id = #{current_user.id}"
    )
    ActiveRecord::Base.connection.execute(
      "SET app.current_user_type = '#{current_user.user_type}'"
    )
  end
  ```

### 4. Infrastructure Security
- Deploy Web Application Firewall (WAF) for all public-facing services
- Use SSL/TLS for all communications (minimum TLS 1.2)
- Implement network segmentation and VPC security groups
- Enable audit logging for all database operations
- Monitor suspicious access patterns

### 5. Database Security
- Enable SSL connections for all database communications
- Use separate database users with minimal required privileges
- Enable audit logging for all DDL and DML operations
- Regular security patches and updates
- Backup encryption and secure storage

### 6. API Security
- Implement rate limiting and request throttling
- Use JWT tokens with appropriate expiration times
- Validate and sanitize all input parameters
- Implement proper CORS policies
- Use API versioning for controlled access

## Monitoring and Incident Response

### 1. Security Monitoring
- Log all authentication attempts (successful and failed)
- Monitor unusual access patterns and privilege escalations
- Track API usage and rate limit violations
- Audit configuration changes

### 2. Incident Response
- Immediate password rotation upon suspected breach
- Disable affected accounts and API keys
- Review audit logs for compromise indicators
- Document and report security incidents

## Compliance Considerations

### Data Protection
- Implement data encryption at rest and in transit
- Provide data export/deletion capabilities (GDPR compliance)
- Maintain audit trails for data access and modifications
- Regular security assessments and penetration testing

### Industry Standards
- Follow OWASP security guidelines
- Implement ASD STIG recommendations where applicable
- Regular security training for development team
- Security code reviews for all changes

## Security Checklist for Deployment

- [ ] All environment variables configured with strong passwords
- [ ] WAF deployed and configured
- [ ] SSL/TLS certificates installed and valid
- [ ] Database connections encrypted
- [ ] Admin users created through secure process
- [ ] Row-level security policies active
- [ ] Audit logging enabled
- [ ] Monitoring and alerting configured
- [ ] Backup and disaster recovery tested
- [ ] Security scanning completed

## Contact and Support

For security-related issues or questions:
- Security team: security@freightmatch.com
- Emergency incidents: +1-XXX-XXX-XXXX
- Documentation: [Security Wiki](internal-link)

---

**Last Updated**: [Current Date]
**Next Review**: [Quarterly Review Date]