#!/bin/bash

# Digital Freight Matching Platform - Development Setup Script
# This script sets up the development environment for the digital freight matching platform

set -e

echo "🚚 Digital Freight Matching Platform - Development Setup"
echo "======================================================="

# Check if required tools are installed
check_prerequisites() {
    echo "📋 Checking prerequisites..."
    
    command -v docker >/dev/null 2>&1 || { echo "❌ Docker is required but not installed. Please install Docker first."; exit 1; }
    command -v docker-compose >/dev/null 2>&1 || { echo "❌ Docker Compose is required but not installed. Please install Docker Compose first."; exit 1; }
    command -v node >/dev/null 2>&1 || { echo "❌ Node.js is required but not installed. Please install Node.js 18+ first."; exit 1; }
    command -v java >/dev/null 2>&1 || { echo "❌ Java is required but not installed. Please install Java 17+ first."; exit 1; }
    
    echo "✅ All prerequisites are installed!"
}

# Create environment file if it doesn't exist
create_env_file() {
    if [ ! -f .env ]; then
        echo "📝 Creating environment file..."
        cat > .env << EOF
# Database Configuration
DATABASE_URL=postgresql://freight_user:freight_pass@localhost:5432/freight_matching
REDIS_URL=redis://localhost:6379

# External APIs
GOOGLE_MAPS_API_KEY=your_google_maps_api_key_here
STRIPE_SECRET_KEY=sk_test_your_stripe_secret_key_here
STRIPE_PUBLISHABLE_KEY=pk_test_your_stripe_publishable_key_here

# Email & SMS
EMAIL_API_KEY=your_sendgrid_api_key_here
SMS_API_KEY=your_twilio_api_key_here

# JWT Configuration
JWT_SECRET=your_super_secret_jwt_key_change_this_in_production
JWT_EXPIRATION=86400

# Kafka Configuration
KAFKA_BOOTSTRAP_SERVERS=localhost:9092

# Application URLs
API_BASE_URL=http://localhost:8080
WEB_APP_URL=http://localhost:3000
ADMIN_DASHBOARD_URL=http://localhost:3002

# Development Settings
SPRING_PROFILES_ACTIVE=dev
NODE_ENV=development
LOG_LEVEL=debug
EOF
        echo "✅ Environment file created! Please update the API keys in .env file."
    else
        echo "✅ Environment file already exists."
    fi
}

# Create directory structure
create_directory_structure() {
    echo "📁 Creating directory structure..."
    
    # Backend directories
    mkdir -p backend/{api-gateway,user-service,load-service,matching-service,route-service,tracking-service,payment-service,notification-service,analytics-service}
    mkdir -p backend/shared/{models,utils,config}
    
    # Frontend directories
    mkdir -p frontend/{web-app,admin-dashboard}/src/{components,pages,services,utils,styles}
    
    # Mobile directory
    mkdir -p mobile/carrier-app/src/{components,screens,services,utils,navigation}
    
    # Infrastructure directories
    mkdir -p infrastructure/{docker,kubernetes,terraform}
    mkdir -p infrastructure/monitoring/{prometheus,grafana}
    
    # Documentation and scripts
    mkdir -p docs/{api,architecture,deployment,user-guides}
    mkdir -p scripts/{build,deploy,migrate}
    mkdir -p tests/{unit,integration,e2e}
    
    echo "✅ Directory structure created!"
}

# Start infrastructure services
start_infrastructure() {
    echo "🚀 Starting infrastructure services..."
    
    docker-compose up -d postgres redis kafka zookeeper mongodb elasticsearch
    
    echo "⏳ Waiting for services to be ready..."
    sleep 30
    
    # Check if PostgreSQL is ready
    echo "🔍 Checking PostgreSQL connection..."
    until docker-compose exec -T postgres pg_isready -U freight_user -d freight_matching; do
        echo "⏳ Waiting for PostgreSQL to be ready..."
        sleep 5
    done
    
    echo "✅ Infrastructure services are running!"
    echo "📊 Access points:"
    echo "   - PostgreSQL: localhost:5432"
    echo "   - Redis: localhost:6379"
    echo "   - MongoDB: localhost:27017"
    echo "   - Elasticsearch: localhost:9200"
    echo "   - Kafka: localhost:9092"
}

# Create basic Spring Boot microservice structure
create_spring_boot_service() {
    local service_name=$1
    local port=$2
    
    service_dir="backend/$service_name"
    
    if [ ! -f "$service_dir/pom.xml" ]; then
        echo "🍃 Creating Spring Boot service: $service_name"
        
        # Create Maven POM file
        cat > "$service_dir/pom.xml" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 
         http://maven.apache.org/xsd/maven-4.0.0.xsd">
    <modelVersion>4.0.0</modelVersion>
    
    <parent>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter-parent</artifactId>
        <version>3.2.0</version>
        <relativePath/>
    </parent>
    
    <groupId>com.freightmatch</groupId>
    <artifactId>$service_name</artifactId>
    <version>1.0.0-SNAPSHOT</version>
    <packaging>jar</packaging>
    
    <name>$service_name</name>
    <description>Digital Freight Matching - $service_name</description>
    
    <properties>
        <java.version>17</java.version>
        <spring-cloud.version>2023.0.0</spring-cloud.version>
    </properties>
    
    <dependencies>
        <!-- Spring Boot Starters -->
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-web</artifactId>
        </dependency>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-data-jpa</artifactId>
        </dependency>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-data-redis</artifactId>
        </dependency>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-security</artifactId>
        </dependency>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-validation</artifactId>
        </dependency>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-actuator</artifactId>
        </dependency>
        
        <!-- Database -->
        <dependency>
            <groupId>org.postgresql</groupId>
            <artifactId>postgresql</artifactId>
            <scope>runtime</scope>
        </dependency>
        
        <!-- Cloud & Microservices -->
        <dependency>
            <groupId>org.springframework.cloud</groupId>
            <artifactId>spring-cloud-starter-netflix-eureka-client</artifactId>
        </dependency>
        <dependency>
            <groupId>org.springframework.kafka</groupId>
            <artifactId>spring-kafka</artifactId>
        </dependency>
        
        <!-- Utilities -->
        <dependency>
            <groupId>org.projectlombok</groupId>
            <artifactId>lombok</artifactId>
            <optional>true</optional>
        </dependency>
        <dependency>
            <groupId>org.mapstruct</groupId>
            <artifactId>mapstruct</artifactId>
            <version>1.5.5.Final</version>
        </dependency>
        
        <!-- Testing -->
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-test</artifactId>
            <scope>test</scope>
        </dependency>
        <dependency>
            <groupId>org.testcontainers</groupId>
            <artifactId>junit-jupiter</artifactId>
            <scope>test</scope>
        </dependency>
        <dependency>
            <groupId>org.testcontainers</groupId>
            <artifactId>postgresql</artifactId>
            <scope>test</scope>
        </dependency>
    </dependencies>
    
    <dependencyManagement>
        <dependencies>
            <dependency>
                <groupId>org.springframework.cloud</groupId>
                <artifactId>spring-cloud-dependencies</artifactId>
                <version>\${spring-cloud.version}</version>
                <type>pom</type>
                <scope>import</scope>
            </dependency>
            <dependency>
                <groupId>org.testcontainers</groupId>
                <artifactId>testcontainers-bom</artifactId>
                <version>1.19.3</version>
                <type>pom</type>
                <scope>import</scope>
            </dependency>
        </dependencies>
    </dependencyManagement>
    
    <build>
        <plugins>
            <plugin>
                <groupId>org.springframework.boot</groupId>
                <artifactId>spring-boot-maven-plugin</artifactId>
                <configuration>
                    <excludes>
                        <exclude>
                            <groupId>org.projectlombok</groupId>
                            <artifactId>lombok</artifactId>
                        </exclude>
                    </excludes>
                </configuration>
            </plugin>
            <plugin>
                <groupId>org.apache.maven.plugins</groupId>
                <artifactId>maven-compiler-plugin</artifactId>
                <version>3.11.0</version>
                <configuration>
                    <source>17</source>
                    <target>17</target>
                    <annotationProcessorPaths>
                        <path>
                            <groupId>org.projectlombok</groupId>
                            <artifactId>lombok</artifactId>
                            <version>\${lombok.version}</version>
                        </path>
                        <path>
                            <groupId>org.mapstruct</groupId>
                            <artifactId>mapstruct-processor</artifactId>
                            <version>1.5.5.Final</version>
                        </path>
                    </annotationProcessorPaths>
                </configuration>
            </plugin>
        </plugins>
    </build>
</project>
EOF
        
        # Create basic directory structure
        mkdir -p "$service_dir/src/main/java/com/freightmatch/$service_name"
        mkdir -p "$service_dir/src/main/resources"
        mkdir -p "$service_dir/src/test/java/com/freightmatch/$service_name"
        
        # Create basic application.yml
        cat > "$service_dir/src/main/resources/application.yml" << EOF
server:
  port: $port

spring:
  application:
    name: $service_name
  
  datasource:
    url: \${DATABASE_URL:jdbc:postgresql://localhost:5432/freight_matching}
    username: freight_user
    password: freight_pass
    driver-class-name: org.postgresql.Driver
  
  jpa:
    hibernate:
      ddl-auto: validate
    show-sql: false
    properties:
      hibernate:
        dialect: org.hibernate.dialect.PostgreSQLDialect
        format_sql: true
  
  redis:
    host: localhost
    port: 6379
    timeout: 2000ms
  
  kafka:
    bootstrap-servers: \${KAFKA_BOOTSTRAP_SERVERS:localhost:9092}
    producer:
      key-serializer: org.apache.kafka.common.serialization.StringSerializer
      value-serializer: org.springframework.kafka.support.serializer.JsonSerializer
    consumer:
      group-id: $service_name-group
      key-deserializer: org.apache.kafka.common.serialization.StringDeserializer
      value-deserializer: org.springframework.kafka.support.serializer.JsonDeserializer

management:
  endpoints:
    web:
      exposure:
        include: health,info,metrics,prometheus
  endpoint:
    health:
      show-details: always

logging:
  level:
    com.freightmatch: DEBUG
    org.springframework.security: DEBUG
  pattern:
    console: "%d{yyyy-MM-dd HH:mm:ss} - %msg%n"
    file: "%d{yyyy-MM-dd HH:mm:ss} [%thread] %-5level %logger{36} - %msg%n"
EOF
        
        # Create basic Dockerfile
        cat > "$service_dir/Dockerfile" << EOF
FROM openjdk:17-jdk-slim

WORKDIR /app

# Copy Maven wrapper and pom.xml
COPY mvnw .
COPY .mvn .mvn
COPY pom.xml .

# Download dependencies
RUN ./mvnw dependency:go-offline -B

# Copy source code
COPY src src

# Build application
RUN ./mvnw clean package -DskipTests

# Expose port
EXPOSE $port

# Run application
CMD ["java", "-jar", "target/$service_name-1.0.0-SNAPSHOT.jar"]
EOF
        
        echo "✅ Created Spring Boot service: $service_name"
    fi
}

# Create React application structure
create_react_app() {
    local app_name=$1
    local app_dir="frontend/$app_name"
    
    if [ ! -f "$app_dir/package.json" ]; then
        echo "⚛️ Creating React application: $app_name"
        
        # Create package.json
        cat > "$app_dir/package.json" << EOF
{
  "name": "$app_name",
  "version": "1.0.0",
  "private": true,
  "dependencies": {
    "@testing-library/jest-dom": "^5.16.5",
    "@testing-library/react": "^13.4.0",
    "@testing-library/user-event": "^14.4.3",
    "@types/jest": "^27.5.2",
    "@types/node": "^16.18.11",
    "@types/react": "^18.0.26",
    "@types/react-dom": "^18.0.10",
    "react": "^18.2.0",
    "react-dom": "^18.2.0",
    "react-router-dom": "^6.6.1",
    "react-scripts": "5.0.1",
    "typescript": "^4.9.4",
    "web-vitals": "^2.1.4",
    "@mui/material": "^5.11.0",
    "@mui/icons-material": "^5.11.0",
    "@emotion/react": "^11.10.5",
    "@emotion/styled": "^11.10.5",
    "axios": "^1.2.2",
    "@reduxjs/toolkit": "^1.9.1",
    "react-redux": "^8.0.5",
    "react-hook-form": "^7.41.5",
    "@hookform/resolvers": "^2.9.10",
    "yup": "^0.32.11"
  },
  "scripts": {
    "start": "react-scripts start",
    "build": "react-scripts build",
    "test": "react-scripts test",
    "eject": "react-scripts eject",
    "lint": "eslint src --ext .ts,.tsx",
    "lint:fix": "eslint src --ext .ts,.tsx --fix"
  },
  "eslintConfig": {
    "extends": [
      "react-app",
      "react-app/jest"
    ]
  },
  "browserslist": {
    "production": [
      ">0.2%",
      "not dead",
      "not op_mini all"
    ],
    "development": [
      "last 1 chrome version",
      "last 1 firefox version",
      "last 1 safari version"
    ]
  },
  "devDependencies": {
    "@types/testing-library__jest-dom": "^5.14.5",
    "eslint": "^8.31.0",
    "eslint-config-prettier": "^8.6.0",
    "eslint-plugin-prettier": "^4.2.1",
    "prettier": "^2.8.2"
  },
  "proxy": "http://localhost:8080"
}
EOF
        
        # Create basic Dockerfile
        cat > "$app_dir/Dockerfile" << EOF
FROM node:18-alpine as builder

WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production

COPY . .
RUN npm run build

FROM nginx:alpine
COPY --from=builder /app/build /usr/share/nginx/html
COPY nginx.conf /etc/nginx/nginx.conf
EXPOSE 3000
CMD ["nginx", "-g", "daemon off;"]
EOF
        
        # Create nginx config
        cat > "$app_dir/nginx.conf" << EOF
events {
    worker_connections 1024;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    server {
        listen 3000;
        server_name localhost;
        root /usr/share/nginx/html;
        index index.html;

        location / {
            try_files \$uri \$uri/ /index.html;
        }

        location /api {
            proxy_pass http://api-gateway:8080;
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;
        }
    }
}
EOF
        
        echo "✅ Created React application: $app_name"
    fi
}

# Main setup function
main() {
    echo "🚀 Starting development environment setup..."
    
    check_prerequisites
    create_env_file
    create_directory_structure
    
    # Create Spring Boot microservices
    create_spring_boot_service "api-gateway" 8080
    create_spring_boot_service "user-service" 8081
    create_spring_boot_service "load-service" 8082
    create_spring_boot_service "matching-service" 8083
    create_spring_boot_service "route-service" 8084
    create_spring_boot_service "tracking-service" 8085
    create_spring_boot_service "payment-service" 8086
    create_spring_boot_service "notification-service" 8087
    create_spring_boot_service "analytics-service" 8088
    
    # Create React applications
    create_react_app "web-app"
    create_react_app "admin-dashboard"
    
    start_infrastructure
    
    echo ""
    echo "🎉 Development environment setup complete!"
    echo ""
    echo "📚 Next steps:"
    echo "1. Update API keys in the .env file"
    echo "2. Start the backend services:"
    echo "   cd backend/api-gateway && ./mvnw spring-boot:run"
    echo "3. Start the frontend applications:"
    echo "   cd frontend/web-app && npm install && npm start"
    echo "4. Access the applications:"
    echo "   - Web App: http://localhost:3000"
    echo "   - Admin Dashboard: http://localhost:3002"
    echo "   - API Gateway: http://localhost:8080"
    echo ""
    echo "📖 For detailed documentation, check the docs/ directory"
    echo "🐛 For issues, check the troubleshooting guide in docs/troubleshooting.md"
}

# Run main function
main "$@"
