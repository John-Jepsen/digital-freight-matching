class Api::V1::RoutesController < ApplicationController
  before_action :authenticate_user!

  # POST /api/v1/routes/optimize
  def optimize
    match = Match.find(params[:match_id])
    authorize_match_access!(match)

    # Extract coordinates from load
    load = match.load
    origin_coords = [load.pickup_latitude, load.pickup_longitude]
    destination_coords = [load.delivery_latitude, load.delivery_longitude]

    # Validate coordinates
    unless origin_coords.all?(&:present?) && destination_coords.all?(&:present?)
      return render json: {
        error: 'Invalid coordinates',
        details: ['Load must have valid pickup and delivery coordinates']
      }, status: :unprocessable_entity
    end

    # Get or create route
    route = match.route || match.build_route
    
    # Set route parameters
    route.assign_attributes(
      origin_latitude: origin_coords[0],
      origin_longitude: origin_coords[1],
      destination_latitude: destination_coords[0],
      destination_longitude: destination_coords[1],
      optimization_type: params[:optimization_type] || 'fastest',
      avoid_highways: params[:avoid_highways] == 'true',
      avoid_tolls: params[:avoid_tolls] == 'true',
      calculated_at: Time.current
    )

    # Calculate route using service
    begin
      route_data = RouteCalculationService.new(route).calculate
      
      if route_data[:success]
        route.assign_attributes(route_data[:route_attributes])
        
        if route.save
          render json: {
            message: 'Route optimized successfully',
            route: detailed_route_response(route)
          }
        else
          render json: {
            error: 'Failed to save route',
            details: route.errors.full_messages
          }, status: :unprocessable_entity
        end
      else
        render json: {
          error: 'Route calculation failed',
          details: route_data[:errors]
        }, status: :unprocessable_entity
      end
    rescue StandardError => e
      render json: {
        error: 'Route optimization service error',
        details: [e.message]
      }, status: :internal_server_error
    end

  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Match not found' }, status: :not_found
  end

  # GET /api/v1/routes/calculate_distance
  def calculate_distance
    origin = parse_coordinates(params[:origin])
    destination = parse_coordinates(params[:destination])

    unless origin && destination
      return render json: {
        error: 'Invalid coordinates',
        details: ['Both origin and destination coordinates are required']
      }, status: :bad_request
    end

    begin
      distance = DistanceCalculationService.new.calculate(origin, destination)
      
      render json: {
        origin: coordinate_response(origin),
        destination: coordinate_response(destination),
        distance: {
          miles: distance[:miles],
          kilometers: distance[:kilometers],
          straight_line_miles: distance[:straight_line_miles],
          driving_time_hours: distance[:driving_time_hours]
        }
      }
    rescue StandardError => e
      render json: {
        error: 'Distance calculation failed',
        details: [e.message]
      }, status: :internal_server_error
    end
  end

  # GET /api/v1/routes/calculate_cost
  def calculate_cost
    origin = parse_coordinates(params[:origin])
    destination = parse_coordinates(params[:destination])
    
    unless origin && destination
      return render json: {
        error: 'Invalid coordinates',
        details: ['Both origin and destination coordinates are required']
      }, status: :bad_request
    end

    # Get optional parameters
    vehicle_type = params[:vehicle_type] || 'dry_van'
    fuel_price = params[:fuel_price]&.to_f || 4.50
    driver_rate = params[:driver_rate]&.to_f || 0.55

    begin
      cost_data = CostCalculationService.new.calculate(
        origin: origin,
        destination: destination,
        vehicle_type: vehicle_type,
        fuel_price: fuel_price,
        driver_rate: driver_rate
      )
      
      render json: {
        origin: coordinate_response(origin),
        destination: coordinate_response(destination),
        cost_breakdown: cost_data
      }
    rescue StandardError => e
      render json: {
        error: 'Cost calculation failed',
        details: [e.message]
      }, status: :internal_server_error
    end
  end

  private

  def authorize_match_access!(match)
    case current_user.user_type
    when 'admin'
      return # Admins can access all matches
    when 'shipper'
      return if match.load.shipper.user == current_user
    when 'carrier'
      return if match.carrier.user == current_user
    when 'driver'
      carrier = current_user.driver_profile&.carrier
      return if carrier && match.carrier == carrier
    end
    
    render json: { error: 'Access denied' }, status: :forbidden
  end

  def parse_coordinates(coord_string)
    return nil unless coord_string.present?
    
    if coord_string.include?(',')
      lat, lng = coord_string.split(',').map(&:strip).map(&:to_f)
      return [lat, lng] if lat.between?(-90, 90) && lng.between?(-180, 180)
    end
    
    nil
  end

  def coordinate_response(coords)
    {
      latitude: coords[0],
      longitude: coords[1],
      formatted: "#{coords[0]}, #{coords[1]}"
    }
  end

  def detailed_route_response(route)
    {
      id: route.id,
      match_id: route.match_id,
      origin: {
        latitude: route.origin_latitude,
        longitude: route.origin_longitude
      },
      destination: {
        latitude: route.destination_latitude,
        longitude: route.destination_longitude
      },
      distance_miles: route.distance_miles,
      estimated_duration: route.estimated_duration,
      estimated_duration_hours: route.estimated_duration_hours,
      optimization_type: route.optimization_type,
      traffic_conditions: route.traffic_conditions,
      costs: {
        fuel_cost: route.fuel_cost,
        toll_cost: route.toll_cost,
        total_cost: route.total_cost,
        cost_per_mile: route.cost_per_mile
      },
      route_quality: {
        fuel_efficiency_score: route.fuel_efficiency_score,
        environmental_impact_score: route.environmental_impact_score,
        route_quality_score: route.route_quality_score
      },
      options: {
        avoid_highways: route.avoid_highways,
        avoid_tolls: route.avoid_tolls
      },
      waypoints: route.waypoints_list,
      instructions: route.instructions_list,
      calculated_at: route.calculated_at,
      expires_at: route.expires_at,
      is_current: route.is_current?
    }
  end
end