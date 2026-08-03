# System Architecture

Comprehensive technical architecture documentation for the Digital Freight Matching Platform.

## High-Level Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   React Web    │    │ React Native    │    │ React Admin     │
│   Frontend      │    │  Mobile App     │    │   Dashboard     │
│  (Port 3000)    │    │  (Planned)      │    │  (Port 3002)    │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         └───────────────────────┼───────────────────────┘
                                 │
                    ┌─────────────────┐
                    │ Rails 8.0.2 API │
                    │ Gateway         │
                    │  (Port 3001)    │
                    └─────────────────┘
                                 │
         ┌───────────────────────┼───────────────────────┐
         │                       │                       │
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│ PostgreSQL 16   │    │ Redis 7         │    │ Docker          │
│ Primary DB      │    │ Cache/Sessions  │    │ Infrastructure  │
│  (Port 5432)    │    │  (Port 6379)    │    │ Orchestration   │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

## System Components

### Frontend Applications

**React Web Application** (`frontend/web-app/`)
- **Purpose**: Main interface for shippers and carriers
- **Technology**: React 18 + TypeScript + Vite
- **Features**: Load posting, carrier matching, real-time tracking
- **Port**: 3000

**Admin Dashboard** (`frontend/admin-dashboard/`)
- **Purpose**: Administrative and analytics interface
- **Technology**: React 18 + TypeScript + Vite
- **Features**: System monitoring, user management, analytics
- **Port**: 3002

### Backend Services

**Rails API Gateway** (`backend/`)
- **Framework**: Ruby on Rails 8.0.2 (API mode)
- **Purpose**: Core business logic and API orchestration
- **Database**: PostgreSQL with ActiveRecord ORM
- **Cache**: Redis for sessions and caching
- **Port**: 3001

### Data Layer

**PostgreSQL Database**
- **Version**: 16 (latest stable)
- **Purpose**: Primary data storage
- **Features**: JSONB support, Row-Level Security, full-text search
- **Port**: 5432

**Redis Cache**
- **Version**: 7 (latest stable)
- **Purpose**: Session storage, caching, background jobs
- **Port**: 6379

## Architecture Evolution Strategy

### Current: Modular Monolith (Phase 1)

**Rationale**: 
- Faster initial development
- Easier debugging and testing
- Lower operational complexity
- Single deployment unit

**Structure**:
```
backend/
├── app/
│   ├── controllers/api/v1/    # API endpoints
│   ├── models/                # ActiveRecord models
│   ├── services/              # Business logic services
│   ├── jobs/                  # Background processing
│   └── channels/              # Real-time features
```

### Future: Microservices (Phase 3)

**Planned Services**:
1. **User Service**: Authentication and profile management
2. **Matching Service**: Core matching algorithms
3. **Route Service**: Route optimization and calculation
4. **Tracking Service**: Real-time shipment tracking
5. **Notification Service**: Alerts and communications
6. **Analytics Service**: Reporting and business intelligence

## Rails Application Structure

### Models (Data Layer)

**Core Entities**:
```ruby
User                    # Base user authentication
├── ShipperProfile     # Shipper-specific data
└── CarrierProfile     # Carrier-specific data
    └── Driver         # Driver management
    └── Vehicle        # Fleet management

Load                   # Freight loads
├── LoadRequirement    # Special requirements
├── CargoDetail       # Cargo specifications
└── Location          # Pickup/delivery locations

Match                  # Load-carrier matches
├── Route             # Optimized routes
└── Shipment          # Active shipments
    └── TrackingEvent # Real-time tracking
```

### Services (Business Logic)

**Core Services**:
- `MatchingAlgorithmService`: Intelligent carrier-load matching
- `RouteCalculationService`: Google Maps integration for routing
- `CostCalculationService`: Transparent cost calculations
- `LoadSearchService`: Advanced load search with scoring
- `DistanceCalculationService`: Geographic calculations

### Controllers (API Layer)

**RESTful API Structure**:
```
/api/v1/
├── auth/              # Authentication endpoints
├── users/             # User management
├── loads/             # Load management
├── carriers/          # Carrier operations
├── matching/          # Matching algorithms
├── routes/            # Route optimization
├── tracking/          # Shipment tracking
└── analytics/         # Dashboard data
```

## Security Architecture

### Authentication & Authorization
- **JWT Tokens**: Stateless authentication
- **Role-Based Access**: Shipper, Carrier, Admin roles
- **Row-Level Security**: Database-level access control

### Data Protection
- **Environment Variables**: All sensitive configuration
- **Encrypted Credentials**: Rails credentials system
- **HTTPS Only**: TLS encryption in production
- **CORS Protection**: Configured for specific origins

### Database Security
- **Row-Level Security (RLS)**: PostgreSQL native security
- **Input Validation**: Comprehensive model validations
- **SQL Injection Protection**: ActiveRecord ORM
- **Audit Logging**: Comprehensive activity tracking

## Deployment Architecture

### Development Environment
```yaml
version: '3.8'
services:
  postgres:    # Database
  redis:       # Cache
  backend:     # Rails API (optional)
  frontend:    # React apps (optional)
```

### Production Considerations

**Scalability**:
- Horizontal scaling with load balancers
- Database read replicas
- Redis clustering for high availability
- CDN for static assets

**Monitoring**:
- Application performance monitoring (APM)
- Database performance tracking
- Real-time error reporting
- Business metrics dashboards

## Data Flow Architecture

### Request Flow
1. **Frontend** → API Gateway (Rails)
2. **Rails** → Services (business logic)
3. **Services** → Models (data access)
4. **Models** → Database (PostgreSQL)

### Real-time Features
1. **ActionCable** for WebSocket connections
2. **Sidekiq** for background job processing
3. **Redis** for pub/sub messaging
4. **Push notifications** for mobile updates

## Development Tools

**Backend**:
- Rails 8.0.2 with Ruby 3.2+
- PostgreSQL 16 with PostGIS extensions
- Redis 7 for caching and jobs
- Sidekiq for background processing

**Frontend**:
- React 18 with TypeScript
- Vite for fast development builds
- Material-UI or similar component library
- React Router for navigation

**DevOps**:
- Docker & Docker Compose
- GitHub Actions for CI/CD
- Nginx for reverse proxy
- SSL/TLS certificates

---

*This architecture provides a solid foundation for scaling from startup to enterprise-level freight matching platform.*
