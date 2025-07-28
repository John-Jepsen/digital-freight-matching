# Digital Freight Matching System - UML Design

## Class Diagram

```mermaid
classDiagram
    class User {
        +Long id
        +String email
        +String password
        +String firstName
        +String lastName
        +String phoneNumber
        +UserType userType
        +Date createdAt
        +Date updatedAt
        +Boolean isActive
        +login()
        +logout()
        +updateProfile()
        +resetPassword()
    }

    class Carrier {
        +Long id
        +Long userId
        +String companyName
        +String dotNumber
        +String mcNumber
        +String insuranceInfo
        +CarrierStatus status
        +Double rating
        +Integer totalDeliveries
        +List~Equipment~ equipment
        +List~Driver~ drivers
        +registerEquipment()
        +updateStatus()
        +viewPerformanceMetrics()
        +manageDrivers()
    }

    class Shipper {
        +Long id
        +Long userId
        +String companyName
        +String businessType
        +String paymentTerms
        +Double creditRating
        +List~Load~ loads
        +postLoad()
        +selectCarrier()
        +trackShipment()
        +makePayment()
        +viewAnalytics()
    }

    class Broker {
        +Long id
        +Long userId
        +String companyName
        +String licenseNumber
        +Double commissionRate
        +List~Customer~ customers
        +List~Transaction~ transactions
        +manageCapacity()
        +negotiateRates()
        +trackCommissions()
        +generateReports()
    }

    class Load {
        +Long id
        +Long shipperId
        +String loadType
        +Double weight
        +Integer palletCount
        +Location pickupLocation
        +Location deliveryLocation
        +DateTime pickupTime
        +DateTime deliveryTime
        +Double offeredRate
        +LoadStatus status
        +String specialRequirements
        +calculateDistance()
        +updateStatus()
        +assignCarrier()
        +generateBOL()
    }

    class Equipment {
        +Long id
        +Long carrierId
        +EquipmentType type
        +String make
        +String model
        +Integer year
        +String plateNumber
        +Double capacity
        +String dimensions
        +EquipmentStatus status
        +updateStatus()
        +scheduleMaintenance()
        +validateCompliance()
    }

    class Driver {
        +Long id
        +Long carrierId
        +String licenseNumber
        +Date licenseExpiry
        +String certifications
        +DriverStatus status
        +Double rating
        +Integer totalMiles
        +updateStatus()
        +recordDrivingHours()
        +submitPOD()
    }

    class Route {
        +Long id
        +Long loadId
        +Location startPoint
        +Location endPoint
        +List~Waypoint~ waypoints
        +Double totalDistance
        +Double estimatedTime
        +Double fuelCost
        +Boolean hasBackhaul
        +calculateOptimalPath()
        +estimateFuelConsumption()
        +identifyRestStops()
        +checkRestrictions()
    }

    class Shipment {
        +Long id
        +Long loadId
        +Long carrierId
        +Long driverId
        +ShipmentStatus status
        +DateTime dispatchTime
        +DateTime deliveryTime
        +Location currentLocation
        +Double completionPercentage
        +updateLocation()
        +updateStatus()
        +notifyStakeholders()
        +generatePOD()
    }

    class Payment {
        +Long id
        +Long shipmentId
        +Long payerId
        +Long payeeId
        +Double amount
        +PaymentStatus status
        +PaymentMethod method
        +DateTime processedAt
        +String transactionId
        +processPayment()
        +generateInvoice()
        +handleDispute()
        +recordTransaction()
    }

    class Location {
        +String address
        +Double latitude
        +Double longitude
        +String city
        +String state
        +String zipCode
        +String facilityType
        +getCoordinates()
        +calculateDistance(Location other)
        +validateAddress()
    }

    class MatchingAlgorithm {
        +generateMatches(Load load)
        +calculateScore(Load load, Carrier carrier)
        +optimizeRoute(List~Load~ loads)
        +findBackhaulOpportunities()
        +minimizeDeadheadMiles()
        +considerDriverPreferences()
        +evaluateCarrierReliability()
    }

    class Notification {
        +Long id
        +Long userId
        +NotificationType type
        +String message
        +DateTime sentAt
        +Boolean isRead
        +NotificationChannel channel
        +send()
        +markAsRead()
        +scheduleReminder()
    }

    class Analytics {
        +generateCarrierReport(Long carrierId)
        +generateShipperReport(Long shipperId)
        +calculateDeadheadReduction()
        +analyzeRouteEfficiency()
        +trackKPIs()
        +generateMarketInsights()
        +predictDemand()
    }

    class Rating {
        +Long id
        +Long raterId
        +Long ratedUserId
        +Integer score
        +String comments
        +DateTime createdAt
        +RatingType type
        +calculateAverageRating()
        +flagInappropriate()
    }

    %% Inheritance relationships
    User <|-- Carrier
    User <|-- Shipper
    User <|-- Broker
    
    %% Composition and Association relationships
    Carrier ||--o{ Equipment : "owns"
    Carrier ||--o{ Driver : "employs"
    Carrier ||--o{ Shipment : "assigned to"
    
    Shipper ||--o{ Load : "posts"
    Shipper ||--o{ Payment : "makes"
    
    Load ||--|| Location : "pickup location"
    Load ||--|| Location : "delivery location"
    Load ||--o| Route : "has"
    Load ||--o| Shipment : "becomes"
    
    Shipment ||--|| Driver : "driven by"
    Shipment ||--o| Payment : "generates"
    
    User ||--o{ Notification : "receives"
    User ||--o{ Rating : "gives/receives"
    
    %% Dependencies
    MatchingAlgorithm ..> Load : processes
    MatchingAlgorithm ..> Carrier : matches
    Analytics ..> Shipment : analyzes
    Analytics ..> Route : optimizes
```

## Sequence Diagram - Load Matching Process

```mermaid
sequenceDiagram
    participant S as Shipper
    participant API as API Gateway
    participant MS as Matching Service
    participant DB as Database
    participant NS as Notification Service
    participant C as Carrier
    participant PS as Payment Service

    S->>+API: POST /loads (new load)
    API->>+DB: Save load details
    DB-->>-API: Load saved
    API->>+MS: Trigger matching algorithm
    API-->>-S: Load posted confirmation

    MS->>+DB: Query available carriers
    DB-->>-MS: Carrier list
    MS->>MS: Calculate match scores
    MS->>MS: Optimize routes
    MS->>+DB: Save match results
    DB-->>-MS: Results saved

    MS->>+NS: Send notifications to matched carriers
    NS->>+C: Push notification with load details
    Note over C: Carrier reviews load details

    C->>+API: POST /loads/{id}/accept
    API->>+DB: Update load status = BOOKED
    DB-->>-API: Status updated
    API->>+NS: Notify shipper of acceptance
    NS->>-S: Send acceptance notification
    API-->>-C: Acceptance confirmed

    Note over C: Driver proceeds to pickup
    C->>+API: PUT /shipments/{id}/status (IN_TRANSIT)
    API->>+DB: Update tracking info
    DB-->>-API: Tracking updated
    API->>+NS: Send tracking updates
    NS->>-S: Real-time location updates
    API-->>-C: Status update confirmed

    Note over C: Delivery completed
    C->>+API: POST /shipments/{id}/pod (proof of delivery)
    API->>+DB: Complete shipment
    DB-->>-API: Shipment completed
    API->>+PS: Trigger payment process
    PS->>+S: Process payment
    S-->>-PS: Payment processed
    PS->>+C: Release payment
    C-->>-PS: Payment received
    PS-->>-API: Payment completed

    API->>+NS: Request rating/feedback
    NS->>S: Rating request
    NS->>-C: Rating request
```

## Use Case Diagram

```mermaid
graph TB
    subgraph "Digital Freight Matching System"
        UC1[Post Load]
        UC2[Search Loads]
        UC3[Book Load]
        UC4[Track Shipment]
        UC5[Process Payment]
        UC6[Generate Reports]
        UC7[Manage Fleet]
        UC8[Optimize Route]
        UC9[Rate & Review]
        UC10[Manage Compliance]
        UC11[Find Backhaul]
        UC12[Negotiate Rates]
    end

    Shipper((Shipper))
    Carrier((Carrier))
    Broker((Broker))
    System((System))

    Shipper --> UC1
    Shipper --> UC4
    Shipper --> UC5
    Shipper --> UC6
    Shipper --> UC9

    Carrier --> UC2
    Carrier --> UC3
    Carrier --> UC4
    Carrier --> UC7
    Carrier --> UC9
    Carrier --> UC10
    Carrier --> UC11

    Broker --> UC1
    Broker --> UC2
    Broker --> UC6
    Broker --> UC12

    System --> UC8
    System --> UC5
```

### Actor-Use Case Relationships

**Shipper Actions:**
- Post Load
- Track Shipment  
- Process Payment
- Generate Reports
- Rate & Review

**Carrier Actions:**
- Search Loads
- Book Load
- Track Shipment
- Manage Fleet
- Rate & Review
- Manage Compliance
- Find Backhaul

**Broker Actions:**
- Post Load (on behalf of shippers)
- Search Loads
- Generate Reports
- Negotiate Rates

**System Actions:**
- Optimize Routes
- Process Payments (automated)

## Activity Diagram - Carrier Load Booking Process

```mermaid
flowchart TD
    A[START] --> B[Carrier Opens Mobile App]
    B --> C[View Available Loads]
    C --> D{Filter Preferences Match?}
    D -->|No| O[Adjust Filters]
    O --> C
    D -->|Yes| E[View Load Details]
    E --> F[Check Route Optimization]
    F --> G[Calculate Potential Revenue]
    G --> H{Profitable?}
    H -->|No| P[Look for Backhaul Options]
    P --> Q{Backhaul Available?}
    Q -->|Yes| R[Book Combined Load]
    Q -->|No| O
    H -->|Yes| I[Submit Load Request]
    I --> J{Request Approved?}
    J -->|No| P
    J -->|Yes| K[Receive Load Assignment]
    K --> L[Navigate to Pickup]
    L --> M[Confirm Pickup]
    M --> N[Start Transit]
    N --> S[Update Location]
    S --> T{Delivered?}
    T -->|No| S
    T -->|Yes| U[Submit POD]
    U --> V[Complete Delivery]
    V --> W[Receive Payment]
    W --> X[Rate Shipper]
    X --> Y[END]
    R --> L
    P --> Z[Back to Load Search]
    Z --> C
```

## Component Diagram

```mermaid
graph TB
    subgraph "Frontend Layer"
        WEB[Web App<br/>React]
        MOBILE[Mobile App<br/>React Native]
        ADMIN[Admin Dashboard]
    end

    subgraph "API Gateway Layer"
        GATEWAY[Spring Cloud Gateway<br/>Authentication<br/>Rate Limiting<br/>Load Balancing]
    end

    subgraph "Microservices Layer"
        USER[User Service<br/>:8081]
        LOAD[Load Service<br/>:8082]
        MATCH[Matching Service<br/>:8083]
        ROUTE[Route Service<br/>:8084]
        TRACK[Tracking Service<br/>:8085]
        PAY[Payment Service<br/>:8086]
        NOTIF[Notification Service<br/>:8087]
        ANALYTICS[Analytics Service<br/>:8088]
    end

    subgraph "Data Layer"
        POSTGRES[PostgreSQL<br/>Primary DB<br/>:5432]
        MONGO[MongoDB<br/>Analytics<br/>:27017]
        REDIS[Redis<br/>Cache<br/>:6379]
        ELASTIC[Elasticsearch<br/>Search<br/>:9200]
    end

    subgraph "External Services"
        MAPS[Google Maps API]
        STRIPE[Stripe Payment]
        EMAIL[SendGrid Email]
        SMS[Twilio SMS]
    end

    WEB --> GATEWAY
    MOBILE --> GATEWAY
    ADMIN --> GATEWAY

    GATEWAY --> USER
    GATEWAY --> LOAD
    GATEWAY --> MATCH
    GATEWAY --> ROUTE
    GATEWAY --> TRACK
    GATEWAY --> PAY
    GATEWAY --> NOTIF
    GATEWAY --> ANALYTICS

    USER --> POSTGRES
    USER --> REDIS
    LOAD --> POSTGRES
    LOAD --> ELASTIC
    MATCH --> POSTGRES
    MATCH --> REDIS
    ROUTE --> POSTGRES
    ROUTE --> MAPS
    TRACK --> POSTGRES
    TRACK --> MONGO
    PAY --> POSTGRES
    PAY --> STRIPE
    NOTIF --> REDIS
    NOTIF --> EMAIL
    NOTIF --> SMS
    ANALYTICS --> MONGO
    ANALYTICS --> ELASTIC
```

### Service Dependencies

```
User Service
├── PostgreSQL (User data)
├── Redis (Session cache)
└── Kafka (User events)

Load Service  
├── PostgreSQL (Load data)
├── Elasticsearch (Load search)
└── Kafka (Load events)

Matching Service
├── PostgreSQL (Match results)
├── Redis (Carrier cache)
├── Kafka (Match events)
└── AI/ML Engine (Algorithms)

Route Service
├── PostgreSQL (Route data)
├── Google Maps API (Routing)
└── Kafka (Route events)

Tracking Service
├── PostgreSQL (Tracking data)
├── MongoDB (Location history)
├── Kafka (Location events)
└── WebSocket (Real-time updates)

Payment Service
├── PostgreSQL (Transaction data)
├── Stripe API (Payment processing)
└── Kafka (Payment events)

Notification Service
├── Redis (Message queue)
├── Kafka (Event consumption)
├── SendGrid (Email)
└── Twilio (SMS)

Analytics Service
├── MongoDB (Analytics data)
├── Elasticsearch (Data indexing)
├── Kafka (Event processing)
└── Apache Spark (Data processing)
```

## Deployment Diagram

```mermaid
graph TB
    subgraph "Internet"
        USERS[Users]
    end

    subgraph "Load Balancer"
        ALB[AWS Application<br/>Load Balancer]
    end

    subgraph "Web Servers"
        WEB1[Web Server 1<br/>Nginx]
        WEB2[Web Server 2<br/>Nginx]
        WEB3[Web Server 3<br/>Nginx]
    end

    subgraph "Application Servers"
        APP1[App Server 1<br/>API Gateway]
        APP2[App Server 2<br/>Microservices]
        APP3[App Server 3<br/>Microservices]
    end

    subgraph "Database Cluster"
        MASTER[Master DB<br/>PostgreSQL]
        SLAVE1[Slave DB 1]
        SLAVE2[Slave DB 2]
    end

    subgraph "Cache & Analytics"
        REDIS_CLUSTER[Redis Cluster]
        MONGO_CLUSTER[MongoDB Cluster]
    end

    USERS --> ALB
    ALB --> WEB1
    ALB --> WEB2
    ALB --> WEB3
    
    WEB1 --> APP1
    WEB2 --> APP2
    WEB3 --> APP3
    
    APP1 --> MASTER
    APP2 --> MASTER
    APP3 --> MASTER
    
    MASTER --> SLAVE1
    MASTER --> SLAVE2
    
    APP1 --> REDIS_CLUSTER
    APP2 --> REDIS_CLUSTER
    APP3 --> REDIS_CLUSTER
    
    APP1 --> MONGO_CLUSTER
    APP2 --> MONGO_CLUSTER
    APP3 --> MONGO_CLUSTER
```

### Kubernetes Deployment Structure

```
digital-freight-matching-k8s/
├── namespaces/
│   ├── production.yaml
│   ├── staging.yaml
│   └── development.yaml
├── api-gateway/
│   ├── deployment.yaml
│   ├── service.yaml
│   └── ingress.yaml
├── microservices/
│   ├── user-service/
│   ├── load-service/
│   ├── matching-service/
│   ├── route-service/
│   ├── tracking-service/
│   ├── payment-service/
│   ├── notification-service/
│   └── analytics-service/
├── databases/
│   ├── postgresql/
│   ├── mongodb/
│   ├── redis/
│   └── elasticsearch/
└── monitoring/
    ├── prometheus/
    └── grafana/
```

## State Diagram - Load Status

```mermaid
stateDiagram-v2
    [*] --> Posted : Shipper creates load
    
    Posted --> Matched : Algorithm finds carriers
    Posted --> Expired : No matches found (72h timeout)
    Posted --> Cancelled : Shipper cancels
    
    Matched --> Booked : Carrier accepts
    Matched --> Posted : All carriers decline
    
    Booked --> InTransit : Pickup confirmed
    Booked --> Cancelled : Cancellation before pickup
    
    InTransit --> Delivered : POD submitted
    InTransit --> Delayed : Schedule issues
    InTransit --> Cancelled : Critical failure
    
    Delayed --> InTransit : Issue resolved
    Delayed --> Cancelled : Cannot complete
    
    Delivered --> PaymentPending : Invoice generated
    
    PaymentPending --> Completed : Payment processed
    PaymentPending --> Disputed : Payment issue
    
    Disputed --> Completed : Dispute resolved
    Disputed --> Cancelled : Dispute unresolved
    
    Expired --> [*]
    Cancelled --> [*]
    Completed --> [*]
    
    note right of Posted
        Initial state when
        shipper creates load
    end note
    
    note left of Matched
        AI algorithm finds
        suitable carriers
    end note
    
    note right of InTransit
        Real-time GPS
        tracking active
    end note
    
    note left of PaymentPending
        Automated billing
        process triggered
    end note
```

### State Transitions Table

| Current State | Event | Next State | Conditions |
|---------------|-------|------------|------------|
| POSTED | Algorithm matches carriers | MATCHED | Available carriers found |
| POSTED | No matches after timeout | EXPIRED | 72 hours elapsed |
| POSTED | Shipper cancels | CANCELLED | Manual cancellation |
| MATCHED | Carrier accepts | BOOKED | Carrier capacity available |
| MATCHED | All carriers decline | POSTED | Return to matching pool |
| BOOKED | Pickup confirmed | IN_TRANSIT | Driver at pickup location |
| BOOKED | Cancellation request | CANCELLED | Before pickup |
| IN_TRANSIT | Delivery issues | DELAYED | Schedule problems |
| IN_TRANSIT | POD submitted | DELIVERED | Successful delivery |
| IN_TRANSIT | Critical failure | CANCELLED | Cannot complete |
| DELAYED | Issue resolved | IN_TRANSIT | Back on schedule |
| DELAYED | Cannot resolve | CANCELLED | Permanent failure |
| DELIVERED | Invoice generated | PAYMENT_PENDING | Billing process |
| PAYMENT_PENDING | Payment processed | COMPLETED | Successful payment |
| PAYMENT_PENDING | Payment dispute | DISPUTED | Payment issues |
| DISPUTED | Dispute resolved | COMPLETED | Issue settled |
| DISPUTED | Dispute unresolved | CANCELLED | Failed transaction |

### PlantUML State Diagram

```plantuml
@startuml
[*] --> Posted

Posted --> Matched : Algorithm finds carriers
Posted --> Expired : No matches found (72h timeout)
Posted --> Cancelled : Shipper cancels

Matched --> Booked : Carrier accepts
Matched --> Posted : All carriers decline

Booked --> InTransit : Pickup confirmed
Booked --> Cancelled : Cancellation before pickup

InTransit --> Delivered : POD submitted
InTransit --> Delayed : Schedule issues
InTransit --> Cancelled : Critical failure

Delayed --> InTransit : Issue resolved
Delayed --> Cancelled : Cannot complete

Delivered --> PaymentPending : Invoice generated

PaymentPending --> Completed : Payment processed
PaymentPending --> Disputed : Payment issue

Disputed --> Completed : Dispute resolved
Disputed --> Cancelled : Dispute unresolved

Expired --> [*]
Cancelled --> [*]
Completed --> [*]

note right of Posted : Initial state when\nshipper creates load

note left of Matched : AI algorithm finds\nsuitable carriers

note right of InTransit : Real-time GPS\ntracking active

note left of PaymentPending : Automated billing\nprocess triggered
@enduml
```

## Data Flow Diagram

### Level 0 - Context Diagram

```mermaid
graph TB
    subgraph "External Entities"
        SHIP[Shippers]
        CARR[Carriers]
        BROK[Brokers]
    end

    subgraph "Digital Freight Matching System"
        SYSTEM[Digital Freight<br/>Matching System]
    end

    SHIP -->|Load Requirements| SYSTEM
    CARR -->|Capacity Info| SYSTEM
    BROK -->|Load Requests| SYSTEM
    
    SYSTEM -->|Load Matching| SHIP
    SYSTEM -->|Payment Confirmation| CARR
    SYSTEM -->|Reports| BROK
```

### Level 1 - Major Processes

```mermaid
graph TB
    subgraph "External Entities"
        SHIP[Shippers]
        CARR[Carriers]
    end

    subgraph "Data Stores"
        USER_DATA[(User Data)]
        LOAD_DATA[(Load Data)]
        ROUTE_DATA[(Route Data)]
        TRANS_DATA[(Transaction Data)]
        ANALYTICS_DATA[(Analytics Data)]
    end

    subgraph "Processes"
        P1[P1: Load Management]
        P2[P2: Matching Engine]
        P3[P3: Route Optimization]
        P4[P4: Tracking System]
    end

    SHIP -->|Load Requirements| P1
    P1 -->|Load Info| P2
    P2 -->|Match Results| P3
    P3 -->|Optimized Routes| P4
    P4 -->|Tracking Data| CARR

    P1 <--> USER_DATA
    P1 <--> LOAD_DATA
    P2 <--> USER_DATA
    P2 <--> LOAD_DATA
    P3 <--> ROUTE_DATA
    P3 <--> LOAD_DATA
    P4 <--> TRANS_DATA
    P4 <--> ANALYTICS_DATA
```

### Data Flow Details

**Process P1: Load Management**
- Inputs: Load requirements from shippers
- Outputs: Load details to matching engine
- Data Stores: User Data, Load Data
- Functions: Validate load, store load details, notify matching engine

**Process P2: Matching Engine**  
- Inputs: Load info, carrier availability
- Outputs: Match results, carrier notifications
- Data Stores: User Data, Load Data
- Functions: AI matching algorithm, score calculation, carrier selection

**Process P3: Route Optimization**
- Inputs: Match results, geographic data
- Outputs: Optimized routes, cost estimates
- Data Stores: Route Data, Load Data
- Functions: Route calculation, fuel optimization, deadhead minimization

**Process P4: Tracking System**
- Inputs: GPS data, shipment status
- Outputs: Real-time updates, completion notifications
- Data Stores: Transaction Data, Analytics Data
- Functions: Location tracking, status updates, performance metrics

## Key Design Patterns Used

### 1. **Microservices Architecture**
- Separate services for user management, load matching, routing, tracking, payments, and notifications
- Each service can be developed, deployed, and scaled independently
- API Gateway pattern for unified interface

### 2. **Event-Driven Architecture**
- Events triggered for load posting, carrier matching, status updates
- Asynchronous processing for real-time notifications
- Event sourcing for audit trails

### 3. **Repository Pattern**
- Data access abstraction for different data stores
- Supports multiple database types (SQL, NoSQL)
- Easier testing and maintenance

### 4. **Strategy Pattern**
- Different matching algorithms based on load type
- Multiple route optimization strategies
- Various pricing models

### 5. **Observer Pattern**
- Real-time notifications for status changes
- Event listeners for analytics and reporting
- Push notifications for mobile apps

### 6. **Factory Pattern**
- Creating different types of loads, equipment, users
- Payment method factories
- Notification channel factories

## Security Considerations

### Authentication & Authorization
- JWT-based authentication
- Role-based access control (RBAC)
- OAuth2 integration for third-party services

### Data Protection
- Encryption at rest and in transit
- PII data masking
- Audit logging for compliance

### API Security
- Rate limiting and throttling
- Input validation and sanitization
- CORS and CSRF protection

## Performance Optimization

### Caching Strategy
- Redis for frequently accessed data
- CDN for static content
- Application-level caching

### Database Optimization
- Read replicas for scaling
- Database partitioning
- Optimized indexes

### Real-time Processing
- WebSocket connections for live updates
- Message queues for asynchronous processing
- Event streaming with Apache Kafka
