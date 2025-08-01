# Quick Start Guide

Get the Digital Freight Matching Platform running in under 5 minutes.

## 🚀 Prerequisites

- **Docker & Docker Compose** (required)
- **Node.js 18+** (for frontend development)
- **Ruby 3.2+** (optional, for local backend development)

## ⚡ One-Command Setup

```bash
git clone https://github.com/John-Jepsen/digital-freight-matching.git
cd digital-freight-matching
./quick-start.sh
```

## 🏃‍♂️ Development Startup Options

### Option A: Hybrid Development (Recommended)
Best for active development with hot reload:

```bash
# Terminal 1: Start infrastructure
docker compose up -d postgres redis

# Terminal 2: Start Rails API (with hot reload)
cd backend
bundle install
bundle exec rails server -p 3001

# Terminal 3: Start React Web App (with hot reload)
cd frontend/web-app
npm install && npm start

# Terminal 4: Start Admin Dashboard (optional)
cd frontend/admin-dashboard
npm install && npm start
```

### Option B: Full Docker (Production-like)
```bash
docker compose up -d
```

## 🌐 Access Points

| Service | URL | Purpose |
|---------|-----|---------|
| **Rails API** | http://localhost:3001 | Backend API and health checks |
| **Web App** | http://localhost:3000 | Main shipper/carrier interface |
| **Admin Dashboard** | http://localhost:3002 | Administrative interface |
| **Health Check** | http://localhost:3001/api/v1/health | System status |

## ✅ Verify Installation

1. **API Health Check**:
   ```bash
   curl http://localhost:3001/api/v1/health
   ```
   Should return: `{"status":"ok","database":"connected","redis":"connected"}`

2. **Frontend Access**:
   - Visit http://localhost:3000 (should show React app)
   - Visit http://localhost:3002 (should show admin dashboard)

## 🔧 Troubleshooting

### Common Issues

**Port conflicts**:
```bash
# Check what's using the ports
lsof -i :3000 -i :3001 -i :3002 -i :5432 -i :6379
```

**Database connection issues**:
```bash
# Reset database
docker compose down postgres
docker volume rm digital-freight-matching_postgres_data
docker compose up -d postgres
```

**Dependencies issues**:
```bash
# Backend
cd backend && bundle install

# Frontend
cd frontend/web-app && rm -rf node_modules && npm install
cd frontend/admin-dashboard && rm -rf node_modules && npm install
```

## 🛠️ Development Workflow

1. **Make backend changes**: Edit files in `backend/`, Rails will auto-reload
2. **Make frontend changes**: Edit files in `frontend/*/src/`, React will hot-reload
3. **Database changes**: Run `rails db:migrate` in backend directory
4. **Add new packages**: Update Gemfile (backend) or package.json (frontend)

## 📝 Next Steps

- [Development Guide](./development.md) - Detailed development setup
- [API Reference](./api-reference.md) - Available endpoints
- [Configuration Guide](./configuration.md) - Environment variables and external services

---
*Need help? Check the [troubleshooting section](./development.md#troubleshooting) or create an issue.*
