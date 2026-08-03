# Copilot Instructions - Digital Freight Matching Platform

## Project Understanding

This is the **Digital Freight Matching Platform** - an AI-powered system that optimizes the trucking industry by reducing empty truck miles (deadhead) through intelligent load-to-carrier matching. The platform addresses a $50+ billion annual problem where 25-35% of truck miles are driven empty.

### Core Mission
Transform freight logistics from reactive manual processes to proactive automated optimization, reducing operational costs by 10-15% and deadhead miles by 25%.

## Coding Guidelines Summary

### Technology Stack
- **Backend**: Ruby on Rails 8.0.2 API-only with PostgreSQL 16 + Redis
- **Frontend**: React 18 + TypeScript + Vite 
- **Infrastructure**: Docker & Docker Compose for development
- **Security**: JWT authentication, Pundit authorization, Row-Level Security (RLS)

### Key Development Patterns

#### Rails Backend Standards
- Use **AASM state machines** for load/shipment lifecycles
- Implement **service objects** for business logic (single responsibility)
- Follow **Pundit policies** for authorization
- Use **ActiveRecord scopes** for common queries
- Implement **comprehensive validations** and error handling
- Apply **Row-Level Security** for data isolation

#### React Frontend Standards
- Use **TypeScript** for all components and hooks
- Implement **custom hooks** for API interactions
- Follow **React Testing Library** best practices
- Use **functional components** with hooks over class components
- Implement proper **loading states** and **error boundaries**

### Database Design Principles
- Use **PostgreSQL indexes** for query optimization
- Implement **geographic queries** with PostGIS for location-based matching
- Apply **JSONB columns** for flexible data storage
- Enforce **business constraints** at database level
- Use **Row-Level Security** policies for data access control

### Security Requirements
- **JWT tokens** with proper expiration and blacklisting
- **Strong password policies** with account lockout
- **Input validation** and **SQL injection prevention**
- **Audit logging** for all sensitive operations
- **Rate limiting** for API endpoints

## Architecture Context

### Current State: Modular Monolith (Phase 1)
- Rails API gateway handling all business logic
- React frontends for web and admin interfaces  
- PostgreSQL with comprehensive business entities
- Redis for caching and background jobs

### Core Business Entities
- **Users** → **ShipperProfiles** / **CarrierProfiles**
- **Loads** (freight postings) → **Matches** (carrier matches) → **Shipments** (active tracking)
- **Vehicles** + **Drivers** (fleet management)
- **Routes** + **TrackingEvents** (logistics optimization)

### Key Business Rules
- **Matching Algorithm**: Distance (30%) + Equipment (20%) + Rating (20%) + Price (15%) + Availability (15%)
- **Pricing Model**: Base rate $1.855/mile + equipment premiums + seasonal factors
- **Performance Metrics**: On-time delivery, deadhead reduction, cost savings
- **Compliance**: DOT/MC numbers, insurance requirements, driver certifications

## When Writing Code

### For Backend Development
```ruby
# Always use service objects for complex business logic
class MatchingAlgorithmService
  def initialize(load, options = {})
    @load = load
    @max_distance = options[:max_distance] || 100
  end

  def call
    # Implementation with proper error handling
    ServiceResult.success(data: matches)
  rescue => e
    ServiceResult.failure(error: e.message)
  end
end

# Use state machines for entity lifecycles
class Load < ApplicationRecord
  include AASM
  
  aasm column: :status do
    state :posted, initial: true
    state :matched, :accepted, :in_transit, :delivered
    
    event :match_with_carrier do
      transitions from: :posted, to: :matched
      after { create_match_record }
    end
  end
end

# Implement proper authorization
class LoadPolicy < ApplicationPolicy
  def create?
    shipper?
  end
  
  def show?
    admin? || owns_load? || carrier_can_view?
  end
end
```

### For Frontend Development
```typescript
// Use TypeScript interfaces for all data structures
interface Load {
  id: number;
  pickupLocation: string;
  deliveryLocation: string;
  price: number;
  status: LoadStatus;
  pickupDatetime: string;
}

// Create custom hooks for API interactions
const useLoads = (filters: LoadFilters) => {
  const [loads, setLoads] = useState<Load[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const fetchLoads = useCallback(async () => {
    // Implementation with proper error handling
  }, [filters]);

  return { loads, loading, error, refetch: fetchLoads };
};

// Implement proper component patterns
const LoadCard: React.FC<{ load: Load; onSelect: (load: Load) => void }> = ({ 
  load, 
  onSelect 
}) => {
  const handleClick = useCallback(() => {
    onSelect(load);
  }, [load, onSelect]);

  return (
    <div className="load-card" onClick={handleClick}>
      {/* Component implementation */}
    </div>
  );
};
```

### For Database Operations
```sql
-- Use proper indexing for query performance
CREATE INDEX idx_loads_status_pickup_date ON loads(status, pickup_datetime);
CREATE INDEX idx_loads_location_search ON loads(pickup_lat, pickup_lng);

-- Implement Row-Level Security
CREATE POLICY loads_access_policy ON loads
  FOR ALL TO authenticated_user
  USING (
    shipper_id = current_shipper_id() OR 
    (status = 'posted' AND current_user_role() = 'carrier') OR
    current_user_role() = 'admin'
  );
```

## Key Business Context

### Industry Knowledge
- **Trucking economics**: $1.855 average cost per mile, 6.5 MPG fuel efficiency
- **Market dynamics**: 70% of trucking companies have only one truck
- **Compliance requirements**: DOT numbers, MC authority, insurance, driver certifications
- **Route optimization**: Google Maps integration for distance/time calculations
- **Equipment types**: dry_van, refrigerated, flatbed, hazmat requirements

### Performance Targets
- **Matching speed**: <30 seconds for carrier matching
- **Deadhead reduction**: 25% improvement over industry average
- **Cost savings**: 10-15% operational cost reduction
- **Uptime**: 99.9% system availability
- **Response time**: <200ms for API endpoints

## Important Considerations

### Security First
- **Never** store sensitive data unencrypted
- **Always** validate input parameters
- **Always** use parameterized queries
- **Always** implement proper authorization checks
- **Always** log security events

### Performance Awareness
- Use database indexes for query optimization
- Implement pagination for large result sets
- Cache expensive calculations in Redis
- Use background jobs for heavy processing
- Monitor query performance regularly

### Business Logic Integrity
- Validate business rules at multiple layers (frontend, backend, database)
- Implement proper state transitions
- Ensure data consistency across related entities
- Handle edge cases (empty results, API failures, network issues)

### Testing Requirements
- **Unit tests** for all business logic
- **Integration tests** for API endpoints
- **End-to-end tests** for critical user workflows
- **Performance tests** for high-load scenarios
- Maintain **85%+ test coverage**

## Reference Materials

The `copilot-instructions/` folder contains detailed guidance:
- `project-context.md` - Business problem and solution overview
- `development-guidelines.md` - Coding standards and patterns
- `business-logic.md` - Core domain models and algorithms
- `api-patterns.md` - RESTful API design and integration
- `database-schema.md` - Data modeling and query optimization
- `security-guidelines.md` - Authentication, authorization, and data protection
- `testing-guidelines.md` - Comprehensive testing strategy

---

**Remember**: This platform directly impacts real trucking operations and costs. Code quality, security, and performance are critical to business success. Always consider the real-world freight logistics context when making technical decisions.
