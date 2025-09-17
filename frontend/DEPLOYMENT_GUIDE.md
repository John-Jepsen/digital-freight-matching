# Frontend Deployment Guide

## Overview
This guide covers deploying the Digital Freight Matching frontend applications to production environments.

## Prerequisites
- Node.js 18+ installed
- Docker (optional, for containerized deployment)
- Access to production servers or cloud platforms

## Quick Start

### 1. Production Build
```bash
# Navigate to frontend directory
cd frontend

# Run the deployment script
./deploy.sh
```

### 2. Manual Build Process
```bash
# Web App
cd web-app
npm ci --only=production
npm run build

# Admin Dashboard
cd ../admin-dashboard
npm ci --only=production
npm run build
```

## Environment Configuration

### Environment Variables
Copy and customize the environment files for your production setup:

**Web App (.env.production):**
```bash
REACT_APP_API_URL=https://api.yourdomain.com
REACT_APP_ENABLE_ANALYTICS=true
REACT_APP_ENABLE_ERROR_REPORTING=true
REACT_APP_SENTRY_DSN=your_sentry_dsn
```

**Admin Dashboard (.env.production):**
```bash
REACT_APP_API_URL=https://api.yourdomain.com
REACT_APP_REQUIRE_2FA=true
REACT_APP_ENABLE_ADMIN_ANALYTICS=true
```

## Deployment Options

### 1. Static File Hosting
Deploy the `build/` folders to any static hosting service:

- **Netlify**: Drag and drop the build folder
- **Vercel**: Connect your GitHub repository
- **AWS S3 + CloudFront**: Upload build files to S3
- **GitHub Pages**: Use the build folder as your site source

### 2. Docker Deployment
```bash
# Build images
docker build -t freight-web ./web-app
docker build -t freight-admin ./admin-dashboard

# Run containers
docker run -p 3000:3000 -e API_URL=https://api.yourdomain.com freight-web
docker run -p 3002:3000 -e API_URL=https://api.yourdomain.com freight-admin
```

### 3. Docker Compose
```yaml
version: '3.8'
services:
  web-app:
    build: ./web-app
    ports:
      - "3000:3000"
    environment:
      - API_URL=https://api.yourdomain.com
    
  admin-dashboard:
    build: ./admin-dashboard
    ports:
      - "3002:3000"
    environment:
      - API_URL=https://api.yourdomain.com
```

### 4. Kubernetes Deployment
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: freight-web
spec:
  replicas: 3
  selector:
    matchLabels:
      app: freight-web
  template:
    metadata:
      labels:
        app: freight-web
    spec:
      containers:
      - name: freight-web
        image: freight-web:latest
        ports:
        - containerPort: 3000
        env:
        - name: API_URL
          value: "https://api.yourdomain.com"
```

## Security Considerations

### SSL/TLS Configuration
Ensure your deployment platform provides HTTPS:
- Use Let's Encrypt for free SSL certificates
- Configure HTTP to HTTPS redirects
- Set secure headers in your reverse proxy

### Content Security Policy
The nginx configuration includes basic CSP headers. Customize for your domain:
```nginx
add_header Content-Security-Policy "default-src 'self'; connect-src 'self' https://api.yourdomain.com;"
```

### API Security
- Use CORS properly configured on your API
- Implement rate limiting
- Use proper authentication tokens

## Performance Optimization

### Nginx Configuration
The included nginx.conf provides:
- Gzip compression
- Static asset caching
- Security headers
- Health check endpoints

### CDN Setup
For better performance, serve static assets through a CDN:
- Upload build assets to CDN
- Update build process to use CDN URLs
- Configure cache headers appropriately

## Monitoring & Debugging

### Health Checks
Both applications include health check endpoints:
- Web App: `GET /health`
- Admin Dashboard: `GET /health`

### Logging
Configure centralized logging:
```bash
# Docker logs
docker logs freight-web
docker logs freight-admin

# Application logs
# Configure Sentry or similar service using REACT_APP_SENTRY_DSN
```

### Performance Monitoring
Monitor key metrics:
- First Contentful Paint (FCP)
- Largest Contentful Paint (LCP)
- Cumulative Layout Shift (CLS)
- Time to Interactive (TTI)

## Troubleshooting

### Common Issues

**Build Failures:**
- Check Node.js version (requires 18+)
- Clear npm cache: `npm cache clean --force`
- Remove node_modules and reinstall

**Runtime Errors:**
- Check browser console for JavaScript errors
- Verify API endpoints are accessible
- Check environment variable configuration

**Performance Issues:**
- Enable gzip compression
- Optimize images and assets
- Implement code splitting
- Use a CDN for static assets

### Debug Mode
For debugging in production:
```bash
# Enable debug logging
REACT_APP_LOG_LEVEL=debug npm run build
```

## Rollback Strategy

### Quick Rollback
1. Keep previous build artifacts
2. Use blue-green deployment strategy
3. Have database migration rollback plan
4. Monitor key metrics after deployment

### Backup Strategy
- Backup environment configurations
- Keep previous Docker images tagged
- Document rollback procedures

## Post-Deployment Checklist

- [ ] Verify health check endpoints
- [ ] Test critical user journeys
- [ ] Check error rates in monitoring
- [ ] Validate analytics data collection
- [ ] Test mobile responsiveness
- [ ] Verify SSL certificate
- [ ] Check API connectivity
- [ ] Monitor performance metrics

## Support

For deployment issues:
1. Check the troubleshooting section above
2. Review application logs
3. Verify environment configuration
4. Test locally with production builds