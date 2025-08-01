# API Reference

Complete REST API documentation for the Digital Freight Matching Platform.

## 🌐 Base Configuration

**Base URL**: `http://localhost:3001`  
**API Version**: v1  
**Content-Type**: `application/json`  
**Authentication**: JWT Bearer tokens  

## 🏥 Health Check Endpoints

### System Health Check
```http
GET /
```

Basic system status check.

**Response**:
```json
{
  "status": "ok",
  "service": "Digital Freight Matching API",
  "version": "1.0.0",
  "timestamp": "2025-07-31T12:00:00Z"
}
```

### Detailed Health Check
```http
GET /api/v1/health
```

Comprehensive system status including database and cache connectivity.

**Response**:
```json
{
  "status": "ok",
  "service": "Digital Freight Matching API",
  "version": "1.0.0",
  "timestamp": "2025-07-31T12:00:00Z",
  "environment": "development",
  "database": "connected",
  "redis": "connected"
}
```

## 🔐 Authentication

### User Registration
```http
POST /api/v1/users/register
```

**Request Body**:
```json
{
  "user": {
    "email": "user@example.com",
    "password": "password123",
    "first_name": "John",
    "last_name": "Doe",
    "phone_number": "+1234567890",
    "user_type": "shipper"
  }
}
```

**Response** (201 Created):
```json
{
  "user": {
    "id": 1,
    "email": "user@example.com",
    "first_name": "John",
    "last_name": "Doe",
    "user_type": "shipper"
  },
  "token": "eyJhbGciOiJIUzI1NiJ9..."
}
```

### User Login
```http
POST /api/v1/users/login
```

**Request Body**:
```json
{
  "email": "user@example.com",
  "password": "password123"
}
```

**Response** (200 OK):
```json
{
  "user": {
    "id": 1,
    "email": "user@example.com",
    "user_type": "shipper"
  },
  "token": "eyJhbGciOiJIUzI1NiJ9..."
}
```

### User Logout
```http
DELETE /api/v1/users/logout
```

**Headers**: `Authorization: Bearer <token>`

**Response** (200 OK):
```json
{
  "message": "Logged out successfully"
}
```

## 👤 User Management

### Get Current User
```http
GET /api/v1/users/profile
```

**Headers**: `Authorization: Bearer <token>`

**Response** (200 OK):
```json
{
  "user": {
    "id": 1,
    "email": "user@example.com",
    "first_name": "John",
    "last_name": "Doe",
    "user_type": "shipper",
    "profile": {
      "company_name": "Acme Shipping",
      "business_type": "logistics"
    }
  }
}
```

### Update User Profile
```http
PUT /api/v1/users/profile
```

**Headers**: `Authorization: Bearer <token>`

**Request Body**:
```json
{
  "user": {
    "first_name": "Jane",
    "phone_number": "+1987654321"
  }
}
```

## 📦 Load Management

### Create Load
```http
POST /api/v1/loads
```

**Headers**: `Authorization: Bearer <token>`

**Request Body**:
```json
{
  "load": {
    "pickup_location": "123 Main St, Atlanta, GA",
    "delivery_location": "456 Oak Ave, Savannah, GA",
    "pickup_datetime": "2025-08-01T10:00:00Z",
    "delivery_datetime": "2025-08-02T14:00:00Z",
    "weight": 15000,
    "price": 2500.00,
    "description": "Electronics shipment",
    "requirements": {
      "equipment_type": "dry_van",
      "hazmat": false,
      "temperature_controlled": false
    },
    "cargo_details": {
      "freight_class": "100",
      "nmfc_code": "50120",
      "pieces": 10,
      "packaging": "pallets"
    }
  }
}
```

**Response** (201 Created):
```json
{
  "load": {
    "id": 1,
    "status": "posted",
    "pickup_location": "123 Main St, Atlanta, GA",
    "delivery_location": "456 Oak Ave, Savannah, GA",
    "distance_miles": 248,
    "estimated_duration_hours": 4.5,
    "price": 2500.00,
    "created_at": "2025-07-31T12:00:00Z"
  }
}
```

### Search Available Loads
```http
GET /api/v1/loads/search
```

**Query Parameters**:
- `origin` - Origin location
- `destination` - Destination location  
- `radius` - Search radius in miles
- `equipment_type` - Equipment requirements
- `min_price` - Minimum price
- `max_price` - Maximum price

**Example**:
```http
GET /api/v1/loads/search?origin=Atlanta,GA&radius=50&equipment_type=dry_van
```

**Response** (200 OK):
```json
{
  "loads": [
    {
      "id": 1,
      "pickup_location": "Atlanta, GA",
      "delivery_location": "Savannah, GA",
      "price": 2500.00,
      "distance_miles": 248,
      "match_score": 95
    }
  ],
  "pagination": {
    "current_page": 1,
    "total_pages": 1,
    "total_count": 1
  }
}
```

### Book Load
```http
POST /api/v1/loads/:id/book
```

**Headers**: `Authorization: Bearer <token>` (Carrier only)

**Response** (200 OK):
```json
{
  "load": {
    "id": 1,
    "status": "booked",
    "carrier_id": 5
  },
  "message": "Load booked successfully"
}
```

## 🚛 Carrier Operations

### Update Carrier Location
```http
PUT /api/v1/carriers/location
```

**Headers**: `Authorization: Bearer <token>`

**Request Body**:
```json
{
  "location": {
    "latitude": 33.7490,
    "longitude": -84.3880,
    "address": "Atlanta, GA"
  }
}
```

### Get Available Loads for Carrier
```http
GET /api/v1/carriers/available_loads
```

**Headers**: `Authorization: Bearer <token>`

**Response** (200 OK):
```json
{
  "loads": [
    {
      "id": 1,
      "pickup_location": "Atlanta, GA",
      "delivery_location": "Savannah, GA",
      "price": 2500.00,
      "distance_from_carrier": 15,
      "match_score": 95
    }
  ]
}
```

### Accept Load
```http
POST /api/v1/carriers/accept_load/:load_id
```

**Headers**: `Authorization: Bearer <token>`

**Response** (200 OK):
```json
{
  "match": {
    "id": 1,
    "load_id": 1,
    "carrier_id": 5,
    "status": "accepted"
  }
}
```

## 🔍 Matching System

### Find Carriers for Load
```http
POST /api/v1/matching/find_carriers
```

**Headers**: `Authorization: Bearer <token>` (Shipper only)

**Request Body**:
```json
{
  "load_id": 1,
  "max_distance": 100,
  "min_rating": 4.0
}
```

**Response** (200 OK):
```json
{
  "carriers": [
    {
      "id": 5,
      "company_name": "Swift Transport",
      "rating": 4.5,
      "distance_miles": 25,
      "match_score": 92,
      "estimated_pickup_time": "2025-08-01T09:30:00Z"
    }
  ]
}
```

### Get Matching Recommendations
```http
GET /api/v1/matching/recommendations
```

**Headers**: `Authorization: Bearer <token>`

**Response** (200 OK):
```json
{
  "recommendations": [
    {
      "load_id": 1,
      "carrier_id": 5,
      "score": 95,
      "reasons": [
        "Optimal route alignment",
        "High carrier rating",
        "Equipment compatibility"
      ]
    }
  ]
}
```

## 🗺️ Route Operations

### Calculate Route
```http
POST /api/v1/routes/calculate
```

**Request Body**:
```json
{
  "origin": "Atlanta, GA",
  "destination": "Savannah, GA",
  "waypoints": ["Macon, GA"],
  "optimization": "fastest"
}
```

**Response** (200 OK):
```json
{
  "route": {
    "distance_miles": 248,
    "duration_hours": 4.2,
    "fuel_cost": 89.28,
    "toll_cost": 15.50,
    "total_cost": 420.75,
    "coordinates": [[33.7490, -84.3880], [32.0835, -83.6527]]
  }
}
```

### Optimize Route
```http
POST /api/v1/routes/optimize
```

**Request Body**:
```json
{
  "loads": [1, 2, 3],
  "carrier_location": "Atlanta, GA",
  "optimization_type": "minimize_deadhead"
}
```

## 📍 Tracking System

### Update Shipment Location
```http
POST /api/v1/tracking/location_update
```

**Headers**: `Authorization: Bearer <token>`

**Request Body**:
```json
{
  "shipment_id": 1,
  "location": {
    "latitude": 33.7490,
    "longitude": -84.3880
  },
  "status": "in_transit",
  "notes": "On schedule"
}
```

### Get Shipment Status
```http
GET /api/v1/tracking/:shipment_id
```

**Response** (200 OK):
```json
{
  "shipment": {
    "id": 1,
    "status": "in_transit",
    "current_location": {
      "latitude": 33.7490,
      "longitude": -84.3880,
      "address": "Atlanta, GA"
    },
    "progress_percentage": 65,
    "estimated_arrival": "2025-08-02T14:30:00Z",
    "tracking_events": [
      {
        "timestamp": "2025-08-01T10:00:00Z",
        "status": "picked_up",
        "location": "Atlanta, GA"
      }
    ]
  }
}
```

## 📊 Analytics

### Get Dashboard Data
```http
GET /api/v1/analytics/dashboard
```

**Headers**: `Authorization: Bearer <token>`

**Response** (200 OK):
```json
{
  "dashboard": {
    "total_loads": 150,
    "active_shipments": 25,
    "completion_rate": 0.95,
    "average_rating": 4.2,
    "revenue_this_month": 125000,
    "recent_activity": [
      {
        "type": "load_completed",
        "timestamp": "2025-07-31T11:30:00Z",
        "description": "Load #123 delivered successfully"
      }
    ]
  }
}
```

## ❌ Error Responses

### Standard Error Format
```json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Validation failed",
    "details": {
      "email": ["can't be blank"],
      "password": ["is too short"]
    }
  }
}
```

### HTTP Status Codes
- `200` - Success
- `201` - Created
- `400` - Bad Request
- `401` - Unauthorized
- `403` - Forbidden
- `404` - Not Found
- `422` - Validation Error
- `500` - Internal Server Error

## 🔧 Rate Limiting

- **Authentication endpoints**: 5 requests per minute
- **Search endpoints**: 60 requests per minute
- **General API**: 100 requests per minute

## 🌐 CORS Configuration

Configured for development origins:
- `http://localhost:3000` (Web App)
- `http://localhost:3002` (Admin Dashboard)

---

*For additional endpoint details, check the Rails routes with `rails routes` command.*
