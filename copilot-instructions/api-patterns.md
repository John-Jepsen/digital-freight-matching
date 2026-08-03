# API Design & Integration Patterns

## RESTful API Architecture

### Base Configuration
- **Base URL**: `http://localhost:3001`
- **API Version**: v1 (path: `/api/v1/`)
- **Content-Type**: `application/json`
- **Authentication**: JWT Bearer tokens
- **CORS**: Configured for development origins

### Standard Response Formats

#### Success Response Structure
```json
{
  "data": {
    "id": 1,
    "type": "load",
    "attributes": {
      "pickup_location": "Atlanta, GA",
      "delivery_location": "Savannah, GA",
      "price": 2500.00,
      "status": "posted"
    },
    "relationships": {
      "shipper": {
        "data": { "id": 1, "type": "shipper" }
      }
    }
  },
  "included": [],
  "meta": {
    "timestamp": "2025-07-31T12:00:00Z"
  }
}
```

#### Error Response Structure
```json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Validation failed",
    "details": {
      "pickup_location": ["can't be blank"],
      "price": ["must be greater than 0"]
    },
    "timestamp": "2025-07-31T12:00:00Z"
  }
}
```

#### Pagination Structure
```json
{
  "data": [...],
  "pagination": {
    "current_page": 1,
    "total_pages": 15,
    "total_count": 150,
    "per_page": 10,
    "next_page": 2,
    "prev_page": null
  },
  "links": {
    "first": "/api/v1/loads?page=1",
    "last": "/api/v1/loads?page=15",
    "next": "/api/v1/loads?page=2",
    "prev": null
  }
}
```

## Authentication & Authorization

### JWT Authentication Implementation
```ruby
# JWT token generation
class AuthenticationService
  SECRET_KEY = Rails.application.secret_key_base

  def self.encode_token(payload)
    payload[:exp] = 24.hours.from_now.to_i
    JWT.encode(payload, SECRET_KEY, 'HS256')
  end

  def self.decode_token(token)
    JWT.decode(token, SECRET_KEY, true, algorithm: 'HS256').first
  rescue JWT::DecodeError, JWT::ExpiredSignature
    nil
  end
end

# Controller authentication
class ApplicationController < ActionController::API
  before_action :authenticate_user!
  
  private
  
  def authenticate_user!
    header = request.headers['Authorization']
    token = header.split(' ').last if header
    
    if token.present?
      decoded = AuthenticationService.decode_token(token)
      @current_user = User.find(decoded['user_id']) if decoded
    end
    
    render json: { error: 'Unauthorized' }, status: :unauthorized unless @current_user
  end
  
  def current_user
    @current_user
  end
end
```

### Authentication Endpoints
```ruby
class Api::V1::AuthController < ApplicationController
  skip_before_action :authenticate_user!, only: [:login, :register]

  # POST /api/v1/auth/register
  def register
    @user = User.new(user_params)
    
    if @user.save
      token = AuthenticationService.encode_token({ user_id: @user.id })
      render json: {
        user: UserSerializer.new(@user),
        token: token
      }, status: :created
    else
      render json: { errors: @user.errors }, status: :unprocessable_entity
    end
  end

  # POST /api/v1/auth/login
  def login
    @user = User.find_by(email: params[:email])
    
    if @user&.authenticate(params[:password])
      token = AuthenticationService.encode_token({ user_id: @user.id })
      render json: {
        user: UserSerializer.new(@user),
        token: token
      }
    else
      render json: { error: 'Invalid credentials' }, status: :unauthorized
    end
  end

  # DELETE /api/v1/auth/logout
  def logout
    # Token invalidation logic (add to blacklist if needed)
    render json: { message: 'Logged out successfully' }
  end
end
```

## Core Resource Endpoints

### Load Management API
```ruby
class Api::V1::LoadsController < ApplicationController
  before_action :set_load, only: [:show, :update, :destroy, :book]
  before_action :authorize_shipper!, only: [:create, :update, :destroy]
  
  # GET /api/v1/loads
  def index
    @loads = policy_scope(Load).includes(:shipper, :load_requirements)
                               .page(params[:page])
                               .per(params[:per_page] || 10)
    
    render json: {
      data: LoadSerializer.new(@loads),
      pagination: pagination_meta(@loads)
    }
  end
  
  # POST /api/v1/loads
  def create
    @load = current_user.shipper_profile.loads.build(load_params)
    
    if @load.save
      # Trigger matching algorithm
      MatchingJob.perform_later(@load.id)
      
      render json: {
        data: LoadSerializer.new(@load)
      }, status: :created
    else
      render json: { errors: @load.errors }, status: :unprocessable_entity
    end
  end
  
  # GET /api/v1/loads/search
  def search
    service = LoadSearchService.new(search_params, current_user)
    result = service.call
    
    if result.success?
      render json: {
        data: LoadSerializer.new(result.data),
        search_meta: result.meta,
        pagination: pagination_meta(result.data)
      }
    else
      render json: { error: result.error }, status: :bad_request
    end
  end
  
  # POST /api/v1/loads/:id/book
  def book
    authorize(@load, :book?)
    
    service = LoadBookingService.new(@load, current_user.carrier_profile)
    result = service.call
    
    if result.success?
      render json: {
        data: MatchSerializer.new(result.data),
        message: 'Load booked successfully'
      }
    else
      render json: { error: result.error }, status: :unprocessable_entity
    end
  end
  
  private
  
  def load_params
    params.require(:load).permit(
      :pickup_location, :delivery_location, :pickup_datetime, :delivery_datetime,
      :weight, :price, :description,
      load_requirements_attributes: [:equipment_type, :hazmat, :temperature_controlled],
      cargo_details_attributes: [:freight_class, :pieces, :packaging]
    )
  end
  
  def search_params
    params.permit(
      :origin, :destination, :radius, :equipment_type,
      :min_price, :max_price, :pickup_date_start, :pickup_date_end
    )
  end
end
```

### Matching System API
```ruby
class Api::V1::MatchingController < ApplicationController
  # POST /api/v1/matching/find_carriers
  def find_carriers
    authorize_shipper!
    
    service = MatchingAlgorithmService.new(
      Load.find(params[:load_id]),
      max_distance: params[:max_distance],
      min_rating: params[:min_rating]
    )
    
    result = service.call
    
    if result.success?
      render json: {
        carriers: CarrierMatchSerializer.new(result.data),
        algorithm_meta: {
          total_candidates: result.meta[:total_candidates],
          scoring_factors: result.meta[:scoring_factors]
        }
      }
    else
      render json: { error: result.error }, status: :internal_server_error
    end
  end
  
  # GET /api/v1/matching/recommendations
  def recommendations
    recommendations = case current_user.user_type
    when 'shipper'
      get_load_recommendations
    when 'carrier'
      get_carrier_recommendations
    else
      []
    end
    
    render json: {
      recommendations: RecommendationSerializer.new(recommendations)
    }
  end
  
  # POST /api/v1/matching/accept
  def accept_match
    @match = Match.find(params[:match_id])
    authorize(@match, :accept?)
    
    if @match.accept!
      render json: {
        match: MatchSerializer.new(@match),
        message: 'Match accepted successfully'
      }
    else
      render json: { errors: @match.errors }, status: :unprocessable_entity
    end
  end
end
```

### Real-time Tracking API
```ruby
class Api::V1::TrackingController < ApplicationController
  # POST /api/v1/tracking/location_update
  def location_update
    @shipment = Shipment.find(params[:shipment_id])
    authorize(@shipment, :update_location?)
    
    service = LocationUpdateService.new(@shipment, location_params)
    result = service.call
    
    if result.success?
      # Broadcast update via ActionCable
      TrackingChannel.broadcast_to(@shipment, {
        location: result.data[:location],
        progress: result.data[:progress],
        estimated_arrival: result.data[:estimated_arrival]
      })
      
      render json: {
        shipment: ShipmentSerializer.new(@shipment),
        tracking_event: TrackingEventSerializer.new(result.data[:tracking_event])
      }
    else
      render json: { error: result.error }, status: :unprocessable_entity
    end
  end
  
  # GET /api/v1/tracking/:shipment_id
  def show
    @shipment = Shipment.find(params[:id])
    authorize(@shipment, :show?)
    
    render json: {
      shipment: ShipmentSerializer.new(@shipment),
      tracking_events: TrackingEventSerializer.new(@shipment.tracking_events.recent),
      real_time_data: {
        progress_percentage: @shipment.progress_percentage,
        estimated_arrival: @shipment.estimated_arrival,
        on_time_status: @shipment.on_time_status
      }
    }
  end
  
  # GET /api/v1/tracking/:shipment_id/history
  def tracking_history
    @shipment = Shipment.find(params[:shipment_id])
    @events = @shipment.tracking_events
                      .page(params[:page])
                      .per(50)
                      .order(occurred_at: :desc)
    
    render json: {
      tracking_events: TrackingEventSerializer.new(@events),
      pagination: pagination_meta(@events)
    }
  end
end
```

## Route Optimization Integration

### Google Maps API Integration
```ruby
class RouteCalculationService
  include GoogleMapsClient
  
  def initialize(origin, destination, waypoints = [])
    @origin = origin
    @destination = destination
    @waypoints = waypoints
    @client = GoogleMaps.new(ENV['GOOGLE_MAPS_API_KEY'])
  end
  
  def calculate_route
    directions = @client.directions(
      @origin,
      @destination,
      {
        waypoints: @waypoints,
        optimize_waypoints: true,
        traffic_model: 'best_guess',
        departure_time: 'now'
      }
    )
    
    route = directions.routes.first
    
    {
      distance_miles: meters_to_miles(route.legs.sum(&:distance_value)),
      duration_hours: route.legs.sum(&:duration_value) / 3600.0,
      traffic_duration_hours: route.legs.sum(&:duration_in_traffic_value) / 3600.0,
      polyline: route.overview_polyline,
      waypoint_order: route.waypoint_order,
      legs: route.legs.map { |leg| format_leg(leg) }
    }
  end
  
  def calculate_cost_analysis(route_data)
    CostCalculationService.new(route_data).call
  end
end

# API endpoint for route calculation
class Api::V1::RoutesController < ApplicationController
  # POST /api/v1/routes/calculate
  def calculate
    service = RouteCalculationService.new(
      params[:origin],
      params[:destination],
      params[:waypoints] || []
    )
    
    route_data = service.calculate_route
    cost_analysis = service.calculate_cost_analysis(route_data)
    
    render json: {
      route: RouteSerializer.new(route_data),
      cost_analysis: cost_analysis,
      optimization_suggestions: generate_optimization_suggestions(route_data)
    }
  end
  
  # POST /api/v1/routes/optimize
  def optimize
    service = RouteOptimizationService.new(
      loads: params[:load_ids],
      carrier_location: params[:carrier_location],
      optimization_type: params[:optimization_type] || 'minimize_deadhead'
    )
    
    result = service.call
    
    render json: {
      optimized_route: OptimizedRouteSerializer.new(result.data),
      savings: result.savings,
      recommendations: result.recommendations
    }
  end
end
```

## Analytics & Reporting API

### Dashboard Data API
```ruby
class Api::V1::AnalyticsController < ApplicationController
  # GET /api/v1/analytics/dashboard
  def dashboard
    case current_user.user_type
    when 'shipper'
      render json: shipper_dashboard_data
    when 'carrier'
      render json: carrier_dashboard_data
    when 'admin'
      render json: admin_dashboard_data
    else
      render json: { error: 'Unauthorized' }, status: :forbidden
    end
  end
  
  # GET /api/v1/analytics/performance
  def performance
    service = PerformanceAnalyticsService.new(
      current_user,
      date_range: params[:date_range],
      metrics: params[:metrics]
    )
    
    result = service.call
    
    render json: {
      performance_data: result.data,
      benchmarks: result.benchmarks,
      trends: result.trends,
      recommendations: result.recommendations
    }
  end
  
  # GET /api/v1/analytics/market_insights
  def market_insights
    authorize_premium_feature!
    
    service = MarketInsightsService.new(
      region: params[:region],
      equipment_type: params[:equipment_type],
      time_period: params[:time_period]
    )
    
    result = service.call
    
    render json: {
      market_data: result.data,
      pricing_trends: result.pricing_trends,
      demand_forecast: result.demand_forecast,
      competitive_analysis: result.competitive_analysis
    }
  end
  
  private
  
  def shipper_dashboard_data
    profile = current_user.shipper_profile
    
    {
      summary: {
        total_loads: profile.loads.count,
        active_shipments: profile.loads.in_transit.count,
        completed_this_month: profile.loads.delivered.where('created_at > ?', 1.month.ago).count,
        avg_cost_per_mile: profile.loads.average(:price) / profile.loads.average('distance_miles')
      },
      recent_activity: profile.loads.recent.limit(5).map { |load| format_activity(load) },
      performance_metrics: calculate_shipper_metrics(profile)
    }
  end
  
  def carrier_dashboard_data
    profile = current_user.carrier_profile
    
    {
      summary: {
        active_loads: profile.matches.active.count,
        revenue_this_month: calculate_monthly_revenue(profile),
        utilization_rate: profile.current_utilization,
        average_rating: profile.rating
      },
      available_loads: profile.recommended_loads.limit(10),
      performance_metrics: calculate_carrier_metrics(profile)
    }
  end
end
```

## WebSocket Integration (ActionCable)

### Real-time Tracking Channel
```ruby
class TrackingChannel < ApplicationCable::Channel
  def subscribed
    @shipment = Shipment.find(params[:shipment_id])
    
    if authorized_to_track?(@shipment)
      stream_for @shipment
      stream_from "tracking_#{@shipment.id}"
    else
      reject
    end
  end
  
  def update_location(data)
    return unless authorized_to_update?(@shipment)
    
    service = LocationUpdateService.new(@shipment, data['location'])
    result = service.call
    
    if result.success?
      broadcast_update(result.data)
    end
  end
  
  private
  
  def authorized_to_track?(shipment)
    current_user == shipment.match.load.shipper.user ||
    current_user == shipment.match.carrier.user ||
    current_user.admin?
  end
  
  def broadcast_update(location_data)
    TrackingChannel.broadcast_to(@shipment, {
      type: 'location_update',
      location: location_data[:location],
      progress: location_data[:progress],
      estimated_arrival: location_data[:estimated_arrival],
      timestamp: Time.current
    })
  end
end
```

## Error Handling & Monitoring

### Comprehensive Error Handling
```ruby
class ApplicationController < ActionController::API
  rescue_from StandardError, with: :handle_standard_error
  rescue_from ActiveRecord::RecordNotFound, with: :handle_not_found
  rescue_from Pundit::NotAuthorizedError, with: :handle_unauthorized
  rescue_from ActionController::ParameterMissing, with: :handle_parameter_missing
  
  private
  
  def handle_standard_error(error)
    Rails.logger.error "#{error.class}: #{error.message}"
    Rails.logger.error error.backtrace.join("\n")
    
    render json: {
      error: {
        code: 'INTERNAL_ERROR',
        message: 'An unexpected error occurred',
        timestamp: Time.current
      }
    }, status: :internal_server_error
  end
  
  def handle_not_found(error)
    render json: {
      error: {
        code: 'NOT_FOUND',
        message: "Resource not found: #{error.message}",
        timestamp: Time.current
      }
    }, status: :not_found
  end
  
  def handle_unauthorized(error)
    render json: {
      error: {
        code: 'FORBIDDEN',
        message: 'Access denied',
        timestamp: Time.current
      }
    }, status: :forbidden
  end
end
```

## API Documentation Standards

### Serializer Patterns
```ruby
class LoadSerializer
  include JSONAPI::Serializer
  
  attributes :id, :pickup_location, :delivery_location, :price, :status, 
             :pickup_datetime, :delivery_datetime, :distance_miles,
             :created_at, :updated_at
  
  belongs_to :shipper
  has_many :load_requirements
  has_many :cargo_details
  has_many :matches
  
  attribute :price_per_mile do |load|
    load.price_per_mile.round(2)
  end
  
  attribute :market_rate_comparison do |load|
    load.market_rate_comparison
  end
  
  attribute :urgency_level do |load|
    if load.pickup_datetime <= 24.hours.from_now
      'urgent'
    elsif load.pickup_datetime <= 72.hours.from_now
      'moderate'
    else
      'normal'
    end
  end
end
```

*These API patterns ensure consistent, secure, and efficient communication between frontend and backend systems while maintaining scalability and reliability.*
