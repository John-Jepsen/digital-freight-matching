#!/bin/bash

# Digital Freight Matching Platform - Quick Start Script
echo "🚚 Digital Freight Matching Platform - Quick Start"
echo "================================================="

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo "❌ Docker is not running. Please start Docker first."
    exit 1
fi

# Check if Docker Compose is available
if ! command -v docker > /dev/null; then
    echo "❌ Docker is not installed. Please install Docker first."
    exit 1
fi

# Check if Docker Compose is available
if ! docker compose version > /dev/null 2>&1 && ! command -v docker-compose > /dev/null; then
    echo "❌ Docker Compose is not available. Please install Docker Compose first."
    exit 1
fi

echo "✅ Docker is available"

# Copy environment file if it doesn't exist
if [ ! -f .env ]; then
    echo "📝 Creating environment file (.env)..."
    cp .env.template .env
    echo "✅ Environment file created. Please update API keys in .env if needed."
else
    echo "✅ Environment file already exists"
fi

echo ""
echo "🚀 Starting infrastructure services..."

# Start database services
echo "Starting PostgreSQL and Redis..."
docker compose up -d postgres redis

# Wait for services to be ready
echo "⏳ Waiting for services to be ready..."
sleep 10

# Check if PostgreSQL is ready
echo "🔍 Checking PostgreSQL connection..."
until docker compose exec postgres pg_isready -U freight_user > /dev/null 2>&1; do
    echo "⏳ Waiting for PostgreSQL to be ready..."
    sleep 2
done

echo "✅ Infrastructure services are running!"

echo ""
echo "🎯 Quick Start Options:"
echo ""
echo "1. 🖥️  Start Rails API Server:"
echo "   cd backend"
echo "   bundle install"
echo "   bundle exec rails server -p 3001"
echo ""
echo "2. ⚛️  Start React Web App:"
echo "   cd frontend/web-app"
echo "   npm start"
echo ""
echo "3. 📊 Start Admin Dashboard:"
echo "   cd frontend/admin-dashboard"
echo "   npm start"
echo ""
echo "4. 🐳 Start everything with Docker:"
echo "   docker compose up -d"
echo ""
echo "📍 Service URLs:"
echo "   - Rails API:        http://localhost:3001"
echo "   - React Web App:    http://localhost:3000"
echo "   - Admin Dashboard:  http://localhost:3002"
echo "   - PostgreSQL:       localhost:5432"
echo "   - Redis:            localhost:6379"
echo ""
echo "🔍 Health Checks:"
echo "   curl http://localhost:3001/           # Basic health"
echo "   curl http://localhost:3001/api/v1/health  # Detailed health"
echo ""
echo "🎉 Ready to start developing!"