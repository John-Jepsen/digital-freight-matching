# Digital Freight Matching Platform - Project Context

## Project Overview
This is a comprehensive digital freight matching platform built to optimize the trucking industry by reducing deadhead miles (empty truck miles) through intelligent load-to-carrier matching algorithms.

### Business Problem
- **25-35% of truck miles are driven empty** - costing the industry $50+ billion annually
- **70% of trucking companies** have only one power unit, leading to market fragmentation
- **Manual, inefficient processes** for matching loads to carriers

### Solution
An AI-powered platform that provides:
- Real-time load-to-carrier optimization
- Route optimization to minimize deadhead miles
- Dynamic pricing with transparent cost breakdowns
- Real-time tracking and automated workflows
- 80% reduction in manual processes

## Technical Architecture

### Current: Modular Monolith (Phase 1)
**Backend**: Ruby on Rails 8.0.2 API-only mode
**Frontend**: React 18 + TypeScript with Vite
**Database**: PostgreSQL 16 with PostGIS extensions
**Cache**: Redis 7 for sessions and background jobs
**Infrastructure**: Docker & Docker Compose

### Evolution Path
- **Phase 1**: Monolithic foundation with Rails API, React frontends, Docker environment
- **Phase 2**: Advanced features, Google Maps integration, real-time tracking
- **Phase 3**: Microservices migration with independent scaling

## Core Components

### Frontend Applications
1. **Web App** (`frontend/web-app/`, port 3000) - Main interface for shippers and carriers
2. **Admin Dashboard** (`frontend/admin-dashboard/`, port 3002) - Analytics and management interface

### Backend Services
- **Rails API Gateway** (`backend/`, port 3001) - Core business logic and API orchestration
- **PostgreSQL Database** (port 5432) - Primary data storage with Row-Level Security
- **Redis Cache** (port 6379) - Sessions, caching, and background job processing

## Key Business Metrics
- **Target**: 25% reduction in deadhead miles
- **Cost Savings**: 10-15% operational cost reduction
- **Efficiency**: 90%+ successful load-carrier matches
- **Performance**: <30 seconds for carrier matching
- **Growth**: $10M+ freight volume Year 1, $200M by Year 3

## Target Users
1. **Shippers**: Companies needing freight transportation
2. **Carriers**: Trucking companies and owner-operators
3. **Drivers**: Individual drivers managing deliveries
4. **Administrators**: Platform operators and analytics users

## Core Features
- Load posting and management
- Intelligent carrier matching algorithms
- Route optimization and calculation
- Real-time shipment tracking
- Dynamic pricing models
- Fleet and driver management
- Analytics and reporting dashboards

## Success Factors
- **Data-Driven Decisions**: Every feature backed by real fleet performance data
- **User-Centric Design**: Streamlined workflows for both shippers and carriers
- **Scalable Architecture**: Built for growth from startup to enterprise scale
- **Security First**: Row-Level Security, JWT authentication, comprehensive audit trails

*This platform transforms freight logistics from reactive manual processes to proactive automated optimization.*
