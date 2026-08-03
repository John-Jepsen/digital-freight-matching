# Digital Freight Matching - Rails Backend

Ruby on Rails 8.0.2 API backend for the Digital Freight Matching Platform.

## Quick Start

```bash
# Install dependencies
bundle install

# Setup database
rails db:create db:migrate db:seed

# Start server
rails server -p 3001
```

## Configuration

### Environment Variables
```bash
# Database
DATABASE_URL=postgresql://freight_user:password@localhost:5432/freight_matching

# Cache
REDIS_URL=redis://:password@localhost:6379/0

# Security
JWT_SECRET_KEY=your_secure_jwt_secret

# External APIs
GOOGLE_MAPS_API_KEY=your_google_maps_api_key
```

## Project Structure

```
backend/
├── app/
│   ├── controllers/api/v1/    # REST API endpoints
│   ├── models/                # ActiveRecord models
│   ├── services/              # Business logic services
│   ├── jobs/                  # Background job classes
│   └── channels/              # WebSocket channels
├── config/                    # Application configuration
├── db/migrate/               # Database migrations
├── spec/                     # RSpec tests
└── Gemfile                   # Ruby dependencies
```

## Testing

```bash
# Run all tests
bundle exec rspec

# Run specific test
bundle exec rspec spec/models/load_spec.rb

# Run with coverage
COVERAGE=true bundle exec rspec
```

## Key Components

### Core Models
- **User**: Authentication and profiles
- **Load**: Freight load management
- **Match**: Load-to-carrier matching
- **Shipment**: Active shipment tracking

### Business Services
- **MatchingAlgorithmService**: Intelligent carrier matching
- **RouteCalculationService**: Google Maps route optimization
- **CostCalculationService**: Transparent cost calculations

### API Controllers
- **LoadsController**: Load management and search
- **CarriersController**: Carrier operations
- **TrackingController**: Real-time shipment tracking

## Database

**PostgreSQL 16** with ActiveRecord ORM
- Row-Level Security (RLS) for data protection
- JSONB for flexible data storage
- Full-text search capabilities
- Geographic data support

## Security

- **JWT Authentication**: Stateless token-based auth
- **Role-Based Access**: Shipper/Carrier/Admin roles
- **Input Validation**: Comprehensive model validations
- **SQL Injection Protection**: ActiveRecord ORM

## Performance

- **Redis Caching**: Route and session caching
- **Database Indexing**: Optimized for search queries
- **Background Jobs**: Async processing with Sidekiq
- **Query Optimization**: Includes/joins for N+1 prevention

## Development

### Rails Console
```bash
rails console

# Example usage:
User.count
Load.where(status: 'posted').count
MatchingAlgorithmService.new.find_matches(load_id: 1)
```

### Database Operations
```bash
# Create migration
rails generate migration AddIndexToLoads

# Run migrations
rails db:migrate

# Seed database
rails db:seed

# Reset database
rails db:reset
```

### Route Information
```bash
# List all routes
rails routes

# Filter API routes
rails routes | grep api
```

## Documentation

For complete documentation, see the main [`docs/`](../docs/) folder:
- [API Reference](../docs/api-reference.md) - Complete endpoint documentation
- [Database Design](../docs/database.md) - Schema and relationships
- [Development Guide](../docs/development.md) - Development workflow

---

**Ruby Version**: 3.2+  
**Rails Version**: 8.0.2  
**Database**: PostgreSQL 16  
**Cache**: Redis 7
