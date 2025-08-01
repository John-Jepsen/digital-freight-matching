# Development Guide

Comprehensive development setup, workflow, and best practices for the Digital Freight Matching Platform.

## 🚀 Quick Setup

### Prerequisites
- **Docker Desktop** (required for database services)
- **Node.js 18+** (for frontend development)
- **Ruby 3.2+** (optional, for local backend development)
- **Git** (version control)

### Initial Setup
```bash
# Clone repository
git clone https://github.com/John-Jepsen/digital-freight-matching.git
cd digital-freight-matching

# Run quick setup script
./quick-start.sh

# Or manual setup:
docker compose up -d postgres redis
cd backend && bundle install
cd ../frontend/web-app && npm install
cd ../admin-dashboard && npm install
```

## 🏗️ Development Architecture

### Recommended Development Flow
```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Local Rails   │    │   Local React   │    │   Docker Infra  │
│      :3001      │    │     :3000       │    │  postgres:5432  │
│                 │    │     :3002       │    │   redis:6379    │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

This hybrid approach provides:
- **Fast backend iteration** with Rails hot reload
- **Instant frontend updates** with Vite HMR
- **Reliable infrastructure** with Docker services

## 🛠️ Development Workflow

### Daily Development Routine

**1. Start Infrastructure**
```bash
# Terminal 1: Infrastructure services
docker compose up -d postgres redis

# Verify services are running
docker compose ps
```

**2. Backend Development**
```bash
# Terminal 2: Rails API with hot reload
cd backend
bundle exec rails server -p 3001

# In development, Rails automatically:
# - Reloads code changes
# - Runs database migrations
# - Shows detailed error pages
```

**3. Frontend Development**
```bash
# Terminal 3: Web application
cd frontend/web-app
npm run dev

# Terminal 4: Admin dashboard (optional)
cd frontend/admin-dashboard  
npm run dev

# Vite provides:
# - Hot module replacement (HMR)
# - Fast compilation
# - Error overlay in browser
```

### Code Change Workflow

**Backend Changes (Rails)**:
1. Edit Ruby files in `backend/app/`
2. Rails automatically reloads on request
3. Database changes: `rails generate migration` → `rails db:migrate`
4. Test changes: `curl http://localhost:3001/api/v1/health`

**Frontend Changes (React)**:
1. Edit TypeScript/React files in `frontend/*/src/`
2. Vite automatically hot-reloads in browser
3. New dependencies: `npm install package-name`
4. Build check: `npm run build`

## 📁 Project Structure Deep Dive

### Backend Structure (`backend/`)
```
backend/
├── app/
│   ├── controllers/
│   │   └── api/v1/          # Versioned API controllers
│   ├── models/              # ActiveRecord models
│   ├── services/            # Business logic services
│   ├── jobs/               # Background job classes
│   └── channels/           # WebSocket channels
├── config/
│   ├── routes.rb           # API route definitions
│   ├── database.yml        # Database configuration
│   └── environments/       # Environment-specific configs
├── db/
│   ├── migrate/            # Database migrations
│   └── seeds.rb           # Sample data for development
├── Gemfile                # Ruby dependencies
└── Dockerfile            # Container configuration
```

**Key Backend Files**:
- `app/controllers/api/v1/` - REST API endpoints
- `app/services/` - Business logic (matching, routing, etc.)
- `config/routes.rb` - API route definitions
- `db/migrate/` - Database schema changes

### Frontend Structure (`frontend/`)
```
frontend/
├── web-app/               # Main user interface
│   ├── src/
│   │   ├── components/    # Reusable React components
│   │   ├── pages/        # Route-based page components
│   │   ├── hooks/        # Custom React hooks
│   │   ├── services/     # API service functions
│   │   └── types/        # TypeScript type definitions
│   ├── public/           # Static assets
│   └── package.json      # Dependencies and scripts
└── admin-dashboard/      # Administrative interface
    └── (similar structure)
```

**Key Frontend Files**:
- `src/services/api.ts` - API communication layer
- `src/components/` - Reusable UI components
- `src/pages/` - Route-specific page components
- `src/types/` - TypeScript interfaces

## 🧪 Testing Strategy

### Backend Testing (Rails)
```bash
cd backend

# Run all tests
bundle exec rspec

# Run specific test file
bundle exec rspec spec/models/load_spec.rb

# Run with coverage
COVERAGE=true bundle exec rspec

# Generate test data
rails db:seed
```

**Test Structure**:
- `spec/models/` - Model unit tests
- `spec/controllers/` - API endpoint tests
- `spec/services/` - Business logic tests
- `spec/requests/` - Integration tests

### Frontend Testing (React)
```bash
cd frontend/web-app

# Run tests
npm test

# Run tests with coverage
npm run test:coverage

# End-to-end tests (if configured)
npm run test:e2e
```

## 🔧 Configuration Management

### Environment Variables
**Development (.env.local)**:
```bash
# Database
POSTGRES_PASSWORD=development_password
POSTGRES_USER=freight_user
POSTGRES_DB=freight_matching

# Redis
REDIS_PASSWORD=redis_development_password

# API Keys (optional for development)
GOOGLE_MAPS_API_KEY=your_development_api_key

# JWT Secret
JWT_SECRET_KEY=development_jwt_secret_key
```

**Backend Configuration**:
```ruby
# config/database.yml
development:
  adapter: postgresql
  encoding: unicode
  database: freight_matching
  pool: <%= ENV.fetch("RAILS_MAX_THREADS") { 5 } %>
  username: freight_user
  password: <%= ENV['POSTGRES_PASSWORD'] %>
  host: localhost
  port: 5432
```

### Rails Configuration
```ruby
# config/environments/development.rb
Rails.application.configure do
  config.cache_classes = false
  config.eager_load = false
  config.consider_all_requests_local = true
  config.server_timing = true
  
  # Enable/disable caching
  if Rails.root.join('tmp', 'caching-dev.txt').exist?
    config.cache_store = :redis_cache_store, { url: ENV['REDIS_URL'] }
  else
    config.cache_store = :null_store
  end
end
```

## 🐛 Debugging & Troubleshooting

### Common Issues & Solutions

**Database Connection Issues**:
```bash
# Check if PostgreSQL is running
docker compose ps postgres

# Reset database
docker compose down postgres
docker volume rm digital-freight-matching_postgres_data
docker compose up -d postgres

# Rebuild and migrate
cd backend
rails db:drop db:create db:migrate db:seed
```

**Port Conflicts**:
```bash
# Find processes using ports
lsof -i :3000  # React web app
lsof -i :3001  # Rails API
lsof -i :3002  # Admin dashboard
lsof -i :5432  # PostgreSQL
lsof -i :6379  # Redis

# Kill conflicting processes
kill -9 <PID>
```

**Dependency Issues**:
```bash
# Backend dependency issues
cd backend
bundle install
bundle update

# Frontend dependency issues
cd frontend/web-app
rm -rf node_modules package-lock.json
npm install

# Clear all caches
npm cache clean --force
```

**Rails-Specific Issues**:
```bash
# Clear Rails cache
rails tmp:clear

# Reset credentials
rails credentials:edit

# Check routes
rails routes | grep api

# Database migration issues
rails db:rollback STEP=1
rails db:migrate
```

### Debugging Tools

**Backend Debugging**:
```ruby
# Add to any controller/service
binding.pry  # Debugging breakpoint (with pry gem)
Rails.logger.debug "Debug message"
puts "Quick debug output"
```

**Frontend Debugging**:
```typescript
// Browser console debugging
console.log('Debug data:', data);
console.table(arrayData);
debugger; // Browser breakpoint

// React DevTools available in browser
```

**API Testing**:
```bash
# Test API endpoints
curl -X GET http://localhost:3001/api/v1/health
curl -X POST http://localhost:3001/api/v1/users/login \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"password"}'

# Use HTTPie (alternative to curl)
http GET localhost:3001/api/v1/health
```

## 📊 Performance Monitoring

### Development Performance Tools

**Rails Performance**:
```bash
# Profile a specific action
rails console
Benchmark.measure { User.all.to_a }

# Memory usage
rails runner 'puts `ps -o pid,rss,command -p #{Process.pid}`'

# SQL query analysis
tail -f log/development.log | grep SQL
```

**Frontend Performance**:
- **React DevTools Profiler**: Monitor component render times
- **Lighthouse**: Web performance auditing
- **Network Tab**: API request/response timing

### Database Query Optimization
```ruby
# N+1 query prevention
User.includes(:carrier_profile).where(user_type: 'carrier')

# Query analysis
Load.joins(:shipper).where(status: 'posted').explain

# Database indexes
rails generate migration AddIndexToLoadsStatus
# add_index :loads, :status
```

## 🚀 Build & Deployment

### Development Builds
```bash
# Backend: No build step needed (interpreted Ruby)
cd backend
rails server

# Frontend: Development server
cd frontend/web-app
npm run dev

# Frontend: Production build test
npm run build
npm run preview
```

### Production Preparation
```bash
# Backend production setup
RAILS_ENV=production rails assets:precompile
RAILS_ENV=production rails db:migrate

# Frontend production build
cd frontend/web-app
npm run build
# Creates dist/ folder with optimized static files
```

## 📝 Git Workflow

### Branch Strategy
```bash
# Feature development
git checkout -b feature/load-matching-enhancement
git add .
git commit -m "feat: improve load matching algorithm"
git push origin feature/load-matching-enhancement

# Create pull request for review
```

### Commit Message Format
```bash
# Use conventional commits
feat: add new load search functionality
fix: resolve carrier location update issue  
docs: update API documentation
test: add unit tests for matching service
refactor: optimize database queries
```

## 🔄 Continuous Development

### File Watching & Auto-reload
- **Rails**: Automatic code reloading in development
- **React**: Vite HMR for instant updates
- **Database**: Migration auto-run in development
- **Styles**: CSS/SCSS hot reload

### Development Productivity Tips
1. **Use multiple terminals** for parallel development
2. **Browser DevTools** for frontend debugging
3. **Rails console** for backend experimentation
4. **Database GUI** (TablePlus, pgAdmin) for data inspection
5. **API testing tools** (Postman, Insomnia) for endpoint testing

---

**Questions or Issues?** Create an issue in the repository or check the troubleshooting section above.  
**Development Chat**: Consider setting up Slack/Discord for team communication.  

*Happy coding! 🚀*
