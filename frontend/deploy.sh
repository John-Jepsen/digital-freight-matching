#!/bin/bash

# Production deployment script for Digital Freight Matching Frontend
set -e

echo "🚀 Starting production deployment..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if we're in the frontend directory
if [ ! -d "web-app" ] || [ ! -d "admin-dashboard" ]; then
    print_error "Please run this script from the frontend directory"
    exit 1
fi

# Check if .env.production files exist
if [ ! -f "web-app/.env.production" ]; then
    print_warning "No .env.production found for web-app, using defaults"
fi

if [ ! -f "admin-dashboard/.env.production" ]; then
    print_warning "No .env.production found for admin-dashboard, using defaults"
fi

# Function to build an app
build_app() {
    local app_name=$1
    local app_dir=$2
    
    print_status "Building $app_name..."
    cd $app_dir
    
    # Install dependencies
    print_status "Installing dependencies for $app_name..."
    npm ci --only=production --silent
    
    # Run security audit
    print_status "Running security audit for $app_name..."
    npm audit --audit-level moderate || print_warning "Security vulnerabilities found in $app_name"
    
    # Build the application
    print_status "Building production bundle for $app_name..."
    NODE_ENV=production npm run build
    
    # Check build output
    if [ -d "build" ]; then
        build_size=$(du -sh build | cut -f1)
        print_status "$app_name build completed. Size: $build_size"
    else
        print_error "$app_name build failed"
        exit 1
    fi
    
    cd ..
}

# Build both applications
build_app "Web App" "web-app"
build_app "Admin Dashboard" "admin-dashboard"

# Build Docker images if Docker is available
if command -v docker &> /dev/null; then
    print_status "Building Docker images..."
    
    # Build web-app image
    print_status "Building web-app Docker image..."
    cd web-app
    docker build -t freight-matching-web:latest -t freight-matching-web:$(date +%Y%m%d) .
    cd ..
    
    # Build admin-dashboard image
    print_status "Building admin-dashboard Docker image..."
    cd admin-dashboard
    docker build -t freight-matching-admin:latest -t freight-matching-admin:$(date +%Y%m%d) .
    cd ..
    
    print_status "Docker images built successfully"
else
    print_warning "Docker not found, skipping Docker image builds"
fi

# Generate deployment summary
print_status "Generating deployment summary..."
echo "
=====================================
🎉 DEPLOYMENT SUMMARY
=====================================
✅ Web App: Built successfully
✅ Admin Dashboard: Built successfully
$(if command -v docker &> /dev/null; then echo "✅ Docker Images: Built successfully"; else echo "⚠️  Docker Images: Skipped (Docker not available)"; fi)

📦 Build Sizes:
- Web App: $(du -sh web-app/build | cut -f1)
- Admin Dashboard: $(du -sh admin-dashboard/build | cut -f1)

🚀 Ready for deployment!

Next steps:
1. Test the built applications locally:
   - Web App: cd web-app && npx serve -s build -p 3000
   - Admin Dashboard: cd admin-dashboard && npx serve -s build -p 3002

2. Deploy Docker images or static files to your hosting platform

3. Update environment variables in production:
   - REACT_APP_API_URL
   - REACT_APP_SENTRY_DSN (if using error reporting)
   - Other environment-specific variables

=====================================
"

print_status "Deployment preparation completed successfully! 🎉"