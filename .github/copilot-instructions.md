# Digital Freight Matching Platform - GitHub Copilot Instructions

**Always reference these instructions first and fallback to search or bash commands only when you encounter unexpected information that does not match the info here.**

## Working Effectively

### Bootstrap and Development Setup

**Prerequisites Installation:**
- Install Ruby 3.2.3+ and bundler: `gem install bundler --user-install` (takes ~2 seconds)
- Install Node.js 18+ for frontend development
- Install Docker and Docker Compose for infrastructure

**Infrastructure Setup:**
- Start infrastructure services: `docker compose up -d postgres redis` (takes ~4.5 seconds, NEVER CANCEL: wait for completion)
- Verify PostgreSQL ready: `docker compose exec postgres pg_isready -U freight_user`

**Backend Rails Setup:**
```bash
cd backend
export PATH="$HOME/.local/share/gem/ruby/3.2.0/bin:$PATH"
bundle config set --local path 'vendor/bundle'  # Configure local gem installation
bundle install                                   # NEVER CANCEL: takes ~11 seconds
bundle exec rails db:create                     # Database setup (takes ~1.7 seconds)
# NOTE: rails db:migrate currently FAILS due to migration version conflicts
# Use pre-existing database or fix migration versions from 8.0 to 7.1 first
```

**Frontend React Setup:**
```bash
cd frontend/web-app
npm install                  # NEVER CANCEL: takes ~48 seconds
# NOTE: npm run build currently FAILS due to missing APITester component
# Tests run but fail: npm test -- --watchAll=false --passWithNoTests (takes ~2.7 seconds)
```

### Development Workflow

**Running the Application:**
- Rails API server: `bundle exec rails server -p 3001` (starts in ~1 second)
- React web app: `npm start` (port 3000) - **BUILD CURRENTLY BROKEN**
- Admin dashboard: `cd frontend/admin-dashboard && npm start` (port 3002)

**Development URLs:**
- Rails API: http://localhost:3001
- React Web App: http://localhost:3000 (broken build)
- Admin Dashboard: http://localhost:3002
- Health Check: http://localhost:3001/api/v1/health

## Critical Issues - DO NOT ATTEMPT

### Backend Issues (BROKEN - DO NOT USE):
- `bundle exec rails db:migrate` - FAILS due to Rails 8.0 migration syntax in Rails 7.1 environment
- `bundle exec rubocop` - NOT AVAILABLE (missing from Gemfile)
- `bundle exec rspec` - FAILS due to missing rails_helper configuration
- Database seeding may fail due to migration issues

### Frontend Issues (BROKEN - DO NOT USE):
- `npm run build` in web-app - FAILS due to missing/malformed APITester component
- Frontend tests fail due to mismatched expectations vs actual component rendering
- Production builds are not functional

## Working Commands and Validation

### Backend Commands That Work:
```bash
# Setup (with measured timings)
bundle install                    # ~11 seconds, NEVER CANCEL
bundle exec rails db:create      # ~1.7 seconds  
bundle exec rails server -p 3001 # Starts in ~1 second

# Development utilities
bundle exec rails console        # Rails console access
bundle exec rails routes         # View available routes
```

### Frontend Commands That Work:
```bash
# Setup
npm install                      # ~48 seconds, NEVER CANCEL
npm test -- --watchAll=false    # ~2.7 seconds (tests run but fail)

# Development
npm start                        # Development server (broken due to build issues)
```

### Infrastructure Commands That Work:
```bash
# Docker services
docker compose up -d postgres redis    # ~4.5 seconds, NEVER CANCEL
docker compose ps                      # View running services
docker compose logs postgres           # View PostgreSQL logs
docker compose logs redis              # View Redis logs
```

## Project Structure

### Backend (`backend/`)
- **Core**: Rails 7.1.5.2 API with Ruby 3.2.3
- **Database**: PostgreSQL with Row-Level Security
- **Key Files**:
  - `Gemfile` - Dependencies (35 gems)
  - `config/application.rb` - Rails configuration
  - `app/controllers/api/v1/` - API endpoints
  - `app/models/` - ActiveRecord models
  - `db/migrate/` - Database migrations (BROKEN: Rails 8.0 syntax)

### Frontend (`frontend/`)
- **Web App** (`frontend/web-app/`) - React 19.1.1 + TypeScript (port 3000)
- **Admin Dashboard** (`frontend/admin-dashboard/`) - React interface (port 3002)
- **Key Files**:
  - `package.json` - Dependencies and scripts
  - `src/components/` - React components (APITester.tsx MISSING)
  - `src/App.tsx` - Main application component

## Testing Strategy

### Backend Testing:
- **Framework**: RSpec 3.13 (available but broken due to missing rails_helper)
- **Command**: `bundle exec rspec` (FAILS - do not use)
- **Coverage**: Tests exist but require configuration fixes

### Frontend Testing:
- **Framework**: Jest + React Testing Library
- **Command**: `npm test -- --watchAll=false --passWithNoTests` (runs in ~2.7 seconds but tests fail)
- **Issues**: Test expectations don't match actual component output

## Known Working Alternatives

Since many standard development commands are broken, use these alternatives:

### Database Work:
- **Instead of migrations**: Use Docker initialization with init-db.sql
- **Database access**: `docker compose exec postgres psql -U freight_user freight_matching`

### Code Quality:
- **Instead of rubocop**: Manual code review or add rubocop to Gemfile first
- **Instead of rspec**: Focus on integration testing via API endpoints

### Build Verification:
- **Backend**: Test Rails server startup: `bundle exec rails server -p 3001`
- **Frontend**: Test dependency installation: `npm install` (skip build verification)

## Architecture Context

### Technology Stack:
- **Backend**: Ruby on Rails 7.1.5.2 API-only mode
- **Frontend**: React 18+ with TypeScript and Vite
- **Database**: PostgreSQL 16 with Redis caching
- **Infrastructure**: Docker Compose for development

### Business Domain:
- Freight matching platform connecting shippers and carriers
- Real-time tracking and route optimization
- JWT authentication with role-based access control
- Geographic queries with PostGIS integration

## Important Considerations

### Security:
- JWT tokens with proper expiration
- PostgreSQL Row-Level Security policies
- Environment variable configuration (no hardcoded secrets)
- CORS protection and rate limiting

### Performance:
- Redis caching for route optimization
- Database indexes for geographic queries
- Background job processing with Sidekiq

### Development Notes:
- **CRITICAL**: Many build and test commands are currently broken
- Focus on API development and testing via HTTP requests
- Use Docker for consistent database state
- Avoid frontend builds until APITester component is fixed

## Validation Workflow

Always validate changes using these working commands:
1. Start infrastructure: `docker compose up -d postgres redis`
2. Install backend deps: `bundle install` (NEVER CANCEL: ~11 seconds)
3. Create database: `bundle exec rails db:create`
4. Start Rails server: `bundle exec rails server -p 3001`
5. Test API endpoint: `curl http://localhost:3001/api/v1/health`
6. Install frontend deps: `npm install` (NEVER CANCEL: ~48 seconds)

**DO NOT** attempt broken commands like `rails db:migrate`, `npm run build`, or `bundle exec rspec` without fixing the underlying issues first.

---

**Built for the freight industry** | **Last Validated**: September 5, 2025