# Digital Freight Matching Platform - Ruby Edition

A comprehensive digital freight matching system built with Ruby on Rails, designed to connect shippers, carriers, and brokers through intelligent algorithms, reducing deadhead trucking and optimizing freight logistics.

## 🚚 Project Overview

This platform addresses key challenges in the trucking industry:
- **Deadhead Trucking Reduction**: Minimize empty truck miles through smart matching
- **Operational Efficiency**: Automate manual freight matching processes  
- **Cost Optimization**: Reduce operational costs through route optimization
- **Real-time Tracking**: Provide visibility throughout the shipping process

## 📊 Business Case

Based on analysis of "INFINITY & BEYOND" fleet data:
- Current operational cost: $1.694/mile
- Route margins: -4% to 24.24%
- Total operational miles: 1,465 miles across 5 routes
- Revenue potential: $2,770.59 with optimization

## 🏗️ Ruby Architecture

### Modular Rails Architecture with Microservice Capability
```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   React Web     │    │ React Native    │    │ Rails Admin     │
│   Frontend      │    │  Mobile App     │    │   Dashboard     │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         └───────────────────────┼───────────────────────┘
                                 │
                    ┌─────────────────┐
                    │ Rails API       │
                    │ Gateway         │
                    └─────────────────┘
                                 │
         ┌───────────────────────┼───────────────────────┐
         │                       │                       │
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│ User Management │    │ Load Management │    │ Matching Engine │
│ Rails Engine    │    │ Rails Engine    │    │ Rails Service   │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│ Route Service   │    │Real-time Track  │    │Payment Service  │
│ Rails + Maps    │    │ActionCable+GPS  │    │Rails + Stripe   │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

## 🛠️ Ruby Technology Stack

### Backend - Ruby/Rails
- **Framework**: Ruby on Rails 8.0+ with API mode
- **Language**: Ruby 3.3+ with modern features
- **Web Server**: Puma with threading
- **Background Jobs**: Sidekiq with Redis
- **Database**: PostgreSQL (Primary), MongoDB (Analytics)
- **Cache**: Redis for sessions, caching, ActionCable
- **Message Queue**: Apache Kafka with Karafka gem
- **API**: REST + JSON API with Jbuilder
- **Real-time**: ActionCable for WebSocket connections

### Key Ruby Gems
- **Authentication**: Devise + JWT
- **Authorization**: Pundit for policies  
- **State Machine**: AASM for load status
- **Background Jobs**: Sidekiq + sidekiq-cron
- **Payments**: Stripe gem
- **Geocoding**: Geocoder gem
- **Search**: Searchkick (Elasticsearch)
- **Testing**: RSpec, FactoryBot, Pact
- **Event Sourcing**: Rails Event Store
- **Functional Programming**: dry-rb ecosystem

### Frontend
- **Web**: React.js with TypeScript
- **Mobile**: React Native
- **State Management**: Redux Toolkit
- **UI Framework**: Material-UI / Tailwind CSS

### Infrastructure
- **Containerization**: Docker with Ruby 3.3 Alpine
- **Orchestration**: Kubernetes or Kamal (Rails 8)
- **CI/CD**: GitHub Actions with Ruby tests
- **Monitoring**: New Relic, Sentry, OpenTelemetry

### External Integrations
- **Maps**: Google Maps API
- **Payments**: Stripe Connect for marketplace
- **Notifications**: SendGrid (email), Twilio (SMS)
- **Analytics**: Custom Ruby analytics service

## 📁 Ruby Project Structure

```
digital-freight-matching/
├── backend/                   # Main Rails application
│   ├── app/
│   │   ├── models/           # ActiveRecord models
│   │   ├── controllers/api/v1/ # API controllers
│   │   ├── jobs/             # Sidekiq background jobs
│   │   ├── services/         # Business logic services
│   │   ├── channels/         # ActionCable channels
│   │   └── serializers/      # JSON API serializers
│   ├── engines/              # Rails Engines for modularity
│   │   ├── user_management/
│   │   ├── load_matching/
│   │   ├── payment_processing/
│   │   └── real_time_tracking/
│   ├── config/
│   │   ├── karafka.rb        # Kafka configuration
│   │   ├── sidekiq.yml       # Background job config
│   │   └── database.yml      # Multi-database setup
│   └── lib/
│       ├── matching_algorithms/ # Ruby ML algorithms
│       └── route_optimization/  # Ruby optimization logic
├── frontend/
│   ├── web-app/              # React web application
│   └── admin-dashboard/      # Rails admin interface
├── mobile/
│   └── carrier-app/          # React Native mobile app
├── infrastructure/
│   ├── docker/
│   │   └── Dockerfile.rails  # Ruby container
│   ├── kamal/                # Rails 8 deployment
│   └── kubernetes/           # K8s manifests for Ruby
└── docs/                     # Documentation

## 🚀 Ruby Quick Start

### Prerequisites
- Ruby 3.3+
- Rails 8.0+
- Node.js 18+ (for frontend)
- Docker & Docker Compose
- PostgreSQL 14+
- Redis 6+
- MongoDB 6+ (for analytics)

### Local Development Setup

1. **Clone the repository**
   ```bash
   git clone https://github.com/your-org/digital-freight-matching.git
   cd digital-freight-matching
   ```

2. **Start infrastructure services**
   ```bash
   docker-compose up -d postgres redis mongodb kafka elasticsearch
   ```

3. **Backend Rails Setup**
   ```bash
   cd backend
   
   # Install Ruby dependencies
   bundle install
   
   # Setup database
   rails db:create db:migrate db:seed
   
   # Start Rails server
   rails server -p 3000
   
   # In separate terminal - Start Sidekiq
   bundle exec sidekiq -C config/sidekiq.yml
   
   # In separate terminal - Start Karafka consumer
   bundle exec karafka server
   ```

4. **Frontend Development**
   ```bash
   cd frontend/web-app
   npm install
   npm start
   ```

5. **Mobile Development**
   ```bash
   cd mobile/carrier-app
   npm install
   npm run android  # or npm run ios
   ```

## 🔧 Ruby Configuration

### Environment Variables
```bash
# Rails Configuration
RAILS_ENV=development
SECRET_KEY_BASE=your_secret_key_base

# Database URLs
DATABASE_URL=postgresql://freight_user:freight_pass@localhost:5432/freight_matching
REDIS_URL=redis://localhost:6379/0
MONGODB_URL=mongodb://freight_user:freight_pass@localhost:27017/freight_analytics
ELASTICSEARCH_URL=http://localhost:9200

# Kafka Configuration
KAFKA_URL=localhost:9092

# External Service APIs
GOOGLE_MAPS_API_KEY=your_maps_api_key
STRIPE_PUBLISHABLE_KEY=your_stripe_publishable_key
STRIPE_SECRET_KEY=your_stripe_secret_key
SENDGRID_API_KEY=your_sendgrid_key
TWILIO_ACCOUNT_SID=your_twilio_sid
TWILIO_AUTH_TOKEN=your_twilio_token

# JWT Configuration (for API authentication)
JWT_SECRET=your_jwt_secret
JWT_EXPIRATION=86400

# Rails-specific settings
RAILS_SERVE_STATIC_FILES=true
RAILS_LOG_TO_STDOUT=true
```

### Ruby Gemfile Overview
```ruby
# Core Rails
gem 'rails', '~> 8.0'
gem 'puma'
gem 'bootsnap'

# Database & Storage
gem 'pg'                    # PostgreSQL
gem 'redis'                 # Redis client
gem 'mongoid'               # MongoDB ODM

# Background Jobs & Messaging
gem 'sidekiq'               # Background processing
gem 'sidekiq-cron'          # Scheduled jobs
gem 'karafka'               # Kafka integration

# Authentication & Authorization
gem 'devise'                # User authentication
gem 'jwt'                   # Token authentication
gem 'pundit'                # Authorization policies

# Business Logic & Validation
gem 'aasm'                  # State machines
gem 'dry-validation'        # Schema validation
gem 'dry-monads'            # Functional programming

# External Integrations
gem 'stripe'                # Payments
gem 'geocoder'              # Address geocoding
gem 'searchkick'            # Elasticsearch
gem 'twilio-ruby'           # SMS
gem 'sendgrid-ruby'         # Email

# Performance & Monitoring
gem 'newrelic_rpm'          # Performance monitoring
gem 'sentry-ruby'           # Error tracking
gem 'rack-cors'             # CORS handling
```

## 📱 Key Features

### For Shippers
- **Load Posting**: Easy load creation with pickup/delivery details
- **Carrier Selection**: AI-powered carrier recommendations
- **Real-time Tracking**: Live shipment visibility
- **Cost Analytics**: Rate optimization and spend analysis
- **Automated Invoicing**: Streamlined payment processing

### For Carriers
- **Smart Load Discovery**: Personalized load recommendations
- **Route Optimization**: Minimize deadhead miles
- **Backhaul Matching**: Find return loads automatically
- **Performance Analytics**: Track earnings and efficiency
- **Mobile-first Design**: Optimized for drivers on the road

### For Brokers
- **Multi-carrier Management**: Manage carrier network
- **Load Consolidation**: Optimize multiple shipments
- **Commission Tracking**: Automated commission calculations
- **Market Intelligence**: Pricing and demand insights
- **Customer Portal**: White-label shipper interface

## 🎯 Key Performance Indicators

### Operational Metrics
- Deadhead mile reduction: Target 25%
- Load-to-truck matching time: < 15 minutes
- Route optimization savings: 10-15%
- On-time delivery rate: > 95%

### Financial Metrics
- Revenue per mile improvement: 12%
- Platform transaction volume: $10M+ annually
- Customer acquisition cost reduction: 30%
- Carrier retention rate: > 85%

## 🔄 Development Workflow

### Git Workflow
```bash
# Feature development
git checkout -b feature/load-matching-algorithm
git commit -m "feat: implement ML-based matching algorithm"
git push origin feature/load-matching-algorithm
# Create PR for review
```

### Testing Strategy
- **Unit Tests**: Jest (Frontend), JUnit (Backend)
- **Integration Tests**: Testcontainers for database tests
- **E2E Tests**: Cypress for critical user journeys
- **Load Tests**: JMeter for performance validation

### CI/CD Pipeline
1. **Code Quality**: ESLint, SonarQube analysis
2. **Testing**: Automated test suite execution
3. **Security**: OWASP dependency check
4. **Build**: Docker image creation
5. **Deploy**: Kubernetes rolling deployment

## 📊 Monitoring & Observability

### Metrics Collection
- **Application Metrics**: Micrometer + Prometheus
- **Business Metrics**: Custom dashboards in Grafana
- **Logging**: Structured logging with ELK stack
- **Tracing**: Distributed tracing with Jaeger

### Alerting
- **SLA Monitoring**: Response time and availability
- **Business Alerts**: Failed matches, payment issues
- **Infrastructure**: Resource utilization thresholds

## 🔐 Security

### Authentication & Authorization
- JWT-based authentication
- Role-based access control (RBAC)
- OAuth2 integration for enterprise SSO

### Data Protection
- Encryption at rest (AES-256)
- Encryption in transit (TLS 1.3)
- PII data masking and anonymization
- GDPR compliance features

### API Security
- Rate limiting and throttling
- Input validation and sanitization
- CORS and CSRF protection
- API key management

## 🌐 Deployment

### Production Environment
```bash
# Deploy to Kubernetes
kubectl apply -f infrastructure/kubernetes/

# Scale services
kubectl scale deployment matching-service --replicas=3

# Monitor deployment
kubectl rollout status deployment/api-gateway
```

### Environment Promotion
- **Development**: Feature branch deployments
- **Staging**: Release candidate testing
- **Production**: Blue-green deployments

## 📈 Roadmap

### Phase 1: MVP (Months 1-3)
- [x] User authentication and management
- [x] Basic load posting and discovery
- [x] Simple matching algorithm
- [x] Mobile app for carriers
- [ ] Payment integration

### Phase 2: Enhanced Features (Months 4-6)
- [ ] Advanced AI matching algorithms
- [ ] Route optimization engine
- [ ] Real-time tracking system
- [ ] Analytics dashboard
- [ ] Broker portal

### Phase 3: Scale & Optimize (Months 7-9)
- [ ] Machine learning improvements
- [ ] TMS integrations
- [ ] Advanced reporting
- [ ] API marketplace

### Phase 4: Market Expansion (Months 10-12)
- [ ] Multi-modal transportation
- [ ] International shipping
- [ ] Autonomous vehicle integration
- [ ] Blockchain for transparency

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests for new functionality
5. Ensure all tests pass
6. Submit a pull request

### Code Standards
- Follow language-specific style guides
- Write meaningful commit messages
- Include documentation for new features
- Maintain test coverage above 80%

## 📜 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 📞 Support

- **Documentation**: [docs.freightmatch.com](https://docs.freightmatch.com)
- **API Reference**: [api.freightmatch.com](https://api.freightmatch.com)
- **Support Email**: support@freightmatch.com
- **Slack Community**: [Join our Slack](https://slack.freightmatch.com)

## 🙏 Acknowledgments

- Industry research from FreightCourse and TruckInfo.net
- Best practices from Convoy and Uber Freight
- Open source tools and libraries that make this possible

---

**Built with ❤️ for the trucking industry**
