# API Documentation - Digital Freight Matching Platform

## Base URL
```
http://localhost:3001
```

## Health Check Endpoints

### System Health Check
**GET** `/`

Returns basic system status.

**Response:**
```json
{
  "status": "ok",
  "service": "Digital Freight Matching API",
  "version": "1.0.0",
  "timestamp": "2025-08-01T04:34:41Z"
}
```

### Detailed Health Check
**GET** `/api/v1/health`

Returns detailed system status including database and cache connectivity.

**Response:**
```json
{
  "status": "ok",
  "service": "Digital Freight Matching API", 
  "version": "1.0.0",
  "timestamp": "2025-08-01T04:34:51Z",
  "environment": "development",
  "database": "connected",
  "redis": "connected"
}
```

## API Endpoints Structure

The following endpoints are configured and ready for implementation:

### User Management
- `POST /api/v1/users/register` - User registration
- `POST /api/v1/users/login` - User login
- `DELETE /api/v1/users/logout` - User logout
- `GET /api/v1/users` - List users
- `GET /api/v1/users/:id` - Get user details
- `PUT /api/v1/users/:id` - Update user
- `DELETE /api/v1/users/:id` - Delete user

### Load Management
- `GET /api/v1/loads` - List all loads
- `POST /api/v1/loads` - Create new load
- `GET /api/v1/loads/:id` - Get load details
- `PUT /api/v1/loads/:id` - Update load
- `DELETE /api/v1/loads/:id` - Delete load
- `POST /api/v1/loads/:id/book` - Book a load
- `POST /api/v1/loads/:id/complete` - Mark load as complete
- `POST /api/v1/loads/:id/cancel` - Cancel a load

### Carrier Management
- `GET /api/v1/carriers` - List all carriers
- `POST /api/v1/carriers` - Create new carrier
- `GET /api/v1/carriers/:id` - Get carrier details
- `PUT /api/v1/carriers/:id` - Update carrier
- `DELETE /api/v1/carriers/:id` - Delete carrier
- `GET /api/v1/carriers/:id/available_loads` - Get available loads for carrier
- `POST /api/v1/carriers/:id/accept_load` - Accept a load
- `POST /api/v1/carriers/:id/update_location` - Update carrier location

### Matching Engine
- `POST /api/v1/matching/find_carriers_for_load` - Find suitable carriers for a load
- `POST /api/v1/matching/find_loads_for_carrier` - Find suitable loads for a carrier
- `GET /api/v1/matching/recommendations` - Get matching recommendations

### Route Optimization
- `POST /api/v1/routes/optimize` - Optimize route for given parameters
- `GET /api/v1/routes/calculate_distance` - Calculate distance between points
- `GET /api/v1/routes/calculate_cost` - Calculate route cost

### Real-time Tracking
- `GET /api/v1/tracking/shipments/:id` - Get shipment tracking info
- `PUT /api/v1/tracking/shipments/:id` - Update shipment status
- `GET /api/v1/tracking/shipments/:id/current_location` - Get current location
- `GET /api/v1/tracking/shipments/:id/status_history` - Get status history

### Analytics
- `GET /api/v1/analytics/dashboard` - Get dashboard data
- `GET /api/v1/analytics/carrier_performance` - Get carrier performance metrics
- `GET /api/v1/analytics/load_metrics` - Get load metrics
- `GET /api/v1/analytics/route_efficiency` - Get route efficiency data

## Authentication

The system is configured with Devise for authentication. JWT tokens can be used for API authentication.

## CORS

Cross-Origin Resource Sharing (CORS) is enabled for all origins in development mode.

## Error Handling

All endpoints return appropriate HTTP status codes:
- `200` - Success
- `201` - Created
- `400` - Bad Request
- `401` - Unauthorized
- `404` - Not Found
- `422` - Unprocessable Entity
- `500` - Internal Server Error

## Database Schema

The system includes the following core tables:
- `users` - User accounts (shippers, carriers, brokers)
- `carriers` - Carrier profiles and equipment info
- `loads` - Load postings with pickup/delivery details
- `load_assignments` - Load-to-carrier assignments

## Next Steps for Implementation

1. **User Authentication**: Implement Devise controllers and JWT handling
2. **Load Management**: Create CRUD operations for loads
3. **Matching Algorithm**: Implement the core matching logic
4. **Real-time Features**: Add ActionCable for live updates
5. **External Integrations**: Connect Google Maps, Stripe, etc.

## Development Commands

```bash
# Start Rails server
cd backend && bundle exec rails server -p 3001

# Database operations
bundle exec rails db:create
bundle exec rails db:migrate
bundle exec rails db:seed

# Generate new controllers
bundle exec rails generate controller api/v1/Users

# Generate models
bundle exec rails generate model Load pickup_address:text delivery_address:text
```