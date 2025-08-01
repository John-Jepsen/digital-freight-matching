class Api::V1::AnalyticsController < ApplicationController
  before_action :authenticate_user!

  # GET /api/v1/analytics/dashboard
  def dashboard
    case current_user.user_type
    when 'shipper'
      shipper_dashboard
    when 'carrier'
      carrier_dashboard
    when 'driver'
      driver_dashboard
    when 'admin'
      admin_dashboard
    else
      render json: { error: 'Analytics not available for this user type' }, status: :forbidden
    end
  end

  # GET /api/v1/analytics/carrier_performance
  def carrier_performance
    authorize_analytics_access!(['admin', 'shipper'])
    
    # Get carrier performance metrics
    carriers = if params[:carrier_id].present?
                 Carrier.where(id: params[:carrier_id])
               else
                 Carrier.joins(:matches).where(matches: { status: 'accepted' }).distinct
               end

    performance_data = carriers.map do |carrier|
      calculate_carrier_performance(carrier)
    end

    render json: {
      carrier_performance: performance_data,
      summary: {
        total_carriers: carriers.count,
        average_rating: performance_data.map { |c| c[:average_rating] }.compact.sum / carriers.count,
        average_on_time: performance_data.map { |c| c[:on_time_percentage] }.compact.sum / carriers.count
      }
    }
  end

  # GET /api/v1/analytics/load_metrics
  def load_metrics
    authorize_analytics_access!(['admin', 'shipper'])
    
    # Date range
    start_date = params[:start_date]&.to_date || 30.days.ago.to_date
    end_date = params[:end_date]&.to_date || Date.current

    loads_scope = Load.where(created_at: start_date..end_date)
    
    # Filter by shipper if not admin
    unless current_user.admin?
      loads_scope = loads_scope.joins(:shipper).where(shippers: { user_id: current_user.id })
    end

    metrics = calculate_load_metrics(loads_scope, start_date, end_date)
    
    render json: {
      date_range: {
        start_date: start_date,
        end_date: end_date
      },
      load_metrics: metrics
    }
  end

  # GET /api/v1/analytics/route_efficiency
  def route_efficiency
    authorize_analytics_access!(['admin', 'carrier'])
    
    # Get routes for analysis
    routes_scope = Route.joins(match: :carrier)
    
    # Filter by carrier if not admin
    unless current_user.admin?
      if current_user.carrier?
        routes_scope = routes_scope.where(matches: { carrier_id: current_user.carrier_profile.id })
      elsif current_user.driver?
        carrier = current_user.driver_profile&.carrier
        routes_scope = routes_scope.where(matches: { carrier_id: carrier.id }) if carrier
      end
    end

    # Date range
    start_date = params[:start_date]&.to_date || 30.days.ago.to_date
    end_date = params[:end_date]&.to_date || Date.current
    
    routes_scope = routes_scope.where(created_at: start_date..end_date)

    efficiency_data = calculate_route_efficiency(routes_scope)
    
    render json: {
      date_range: {
        start_date: start_date,
        end_date: end_date
      },
      route_efficiency: efficiency_data
    }
  end

  # GET /api/v1/analytics/market_trends
  def market_trends
    authorize_analytics_access!(['admin'])
    
    # Market analysis
    trends = calculate_market_trends
    
    render json: {
      market_trends: trends,
      generated_at: Time.current
    }
  end

  # GET /api/v1/analytics/financial_summary
  def financial_summary
    case current_user.user_type
    when 'shipper'
      shipper_financial_summary
    when 'carrier'
      carrier_financial_summary
    when 'admin'
      admin_financial_summary
    else
      render json: { error: 'Financial analytics not available for this user type' }, status: :forbidden
    end
  end

  private

  def authorize_analytics_access!(allowed_types)
    unless allowed_types.include?(current_user.user_type)
      render json: { error: 'Access denied for this analytics endpoint' }, status: :forbidden
    end
  end

  def shipper_dashboard
    shipper = current_user.shipper_profile
    return render json: { error: 'Shipper profile required' }, status: :bad_request unless shipper

    # Last 30 days metrics
    loads = shipper.loads.where('created_at >= ?', 30.days.ago)
    
    dashboard_data = {
      overview: {
        total_loads_posted: loads.count,
        loads_matched: loads.joins(:active_match).count,
        loads_completed: loads.where(status: 'delivered').count,
        active_loads: loads.where(status: ['posted', 'matched', 'accepted', 'picked_up', 'in_transit']).count
      },
      financial: {
        total_spend: loads.sum(:total_rate),
        average_rate_per_mile: calculate_average_rate_per_mile(loads),
        cost_savings: calculate_cost_savings(loads)
      },
      performance: {
        average_time_to_match: calculate_average_time_to_match(shipper),
        on_time_delivery_rate: calculate_on_time_delivery_rate(loads),
        carrier_rating_average: calculate_average_carrier_rating(loads)
      },
      recent_activity: {
        recent_loads: loads.order(created_at: :desc).limit(5).map { |load| load_summary(load) },
        upcoming_deliveries: loads.where('delivery_date >= ?', Date.current).order(:delivery_date).limit(5).map { |load| load_summary(load) }
      }
    }

    render json: { dashboard: dashboard_data }
  end

  def carrier_dashboard
    carrier = current_user.carrier_profile
    return render json: { error: 'Carrier profile required' }, status: :bad_request unless carrier

    # Last 30 days metrics
    matches = carrier.matches.where('created_at >= ?', 30.days.ago)
    
    dashboard_data = {
      overview: {
        loads_completed: matches.where(status: 'accepted').joins(:shipment).where(shipments: { status: 'delivered' }).count,
        loads_in_progress: matches.where(status: 'accepted').joins(:shipment).where(shipments: { status: ['picked_up', 'in_transit'] }).count,
        revenue_earned: matches.where(status: 'accepted').sum(:rate_accepted),
        average_load_value: matches.where(status: 'accepted').average(:rate_accepted)
      },
      performance: {
        on_time_percentage: carrier.on_time_percentage,
        average_rating: carrier.average_rating,
        total_miles_driven: calculate_total_miles_driven(matches),
        fuel_efficiency: calculate_fuel_efficiency(matches)
      },
      fleet: {
        active_vehicles: carrier.vehicles.active.count,
        available_drivers: carrier.drivers.active.count,
        utilization_rate: calculate_fleet_utilization(carrier)
      },
      recent_activity: {
        recent_matches: matches.order(created_at: :desc).limit(5).map { |match| match_summary(match) },
        active_shipments: carrier.active_shipments.limit(5).map { |shipment| shipment_summary(shipment) }
      }
    }

    render json: { dashboard: dashboard_data }
  end

  def driver_dashboard
    driver = current_user.driver_profile
    return render json: { error: 'Driver profile required' }, status: :bad_request unless driver

    carrier = driver.carrier
    return render json: { error: 'Driver must be associated with a carrier' }, status: :bad_request unless carrier

    # Last 30 days metrics for driver's loads
    driver_matches = carrier.matches.where('created_at >= ?', 30.days.ago)
    
    dashboard_data = {
      overview: {
        loads_completed: driver_matches.joins(:shipment).where(shipments: { status: 'delivered' }).count,
        miles_driven: calculate_driver_miles(driver_matches),
        hours_driven: calculate_driver_hours(driver_matches),
        earnings: driver_matches.where(status: 'accepted').sum(:rate_accepted)
      },
      performance: {
        on_time_percentage: calculate_driver_on_time_percentage(driver),
        safety_score: driver.safety_score,
        fuel_efficiency: calculate_driver_fuel_efficiency(driver),
        average_rating: driver.average_rating
      },
      compliance: {
        hos_status: driver.current_hos_status,
        license_status: driver.license_status,
        next_inspection_due: driver.next_inspection_date,
        certifications: driver.active_certifications
      },
      current_load: current_load_info(driver)
    }

    render json: { dashboard: dashboard_data }
  end

  def admin_dashboard
    # System-wide metrics
    dashboard_data = {
      overview: {
        total_users: User.count,
        total_loads: Load.count,
        total_matches: Match.count,
        active_shipments: Shipment.where(status: ['picked_up', 'in_transit']).count
      },
      financial: {
        total_platform_revenue: calculate_platform_revenue,
        average_load_value: Load.average(:total_rate),
        total_transaction_volume: Load.sum(:total_rate)
      },
      growth: {
        new_users_this_month: User.where('created_at >= ?', 1.month.ago).count,
        loads_posted_this_month: Load.where('created_at >= ?', 1.month.ago).count,
        matches_made_this_month: Match.where('created_at >= ?', 1.month.ago).count
      },
      performance: {
        average_match_time: calculate_system_average_match_time,
        platform_utilization: calculate_platform_utilization,
        customer_satisfaction: calculate_average_system_rating
      }
    }

    render json: { dashboard: dashboard_data }
  end

  def calculate_carrier_performance(carrier)
    matches = carrier.matches.where(status: 'accepted')
    completed_shipments = matches.joins(:shipment).where(shipments: { status: 'delivered' })
    
    {
      carrier_id: carrier.id,
      company_name: carrier.company_name,
      total_loads: matches.count,
      completed_loads: completed_shipments.count,
      on_time_percentage: carrier.on_time_percentage,
      average_rating: carrier.average_rating,
      total_revenue: matches.sum(:rate_accepted),
      average_load_value: matches.average(:rate_accepted),
      active_since: carrier.created_at
    }
  end

  def calculate_load_metrics(loads_scope, start_date, end_date)
    total_loads = loads_scope.count
    
    {
      total_loads: total_loads,
      loads_by_status: loads_scope.group(:status).count,
      loads_by_equipment: loads_scope.group(:equipment_type).count,
      average_weight: loads_scope.average(:weight),
      average_distance: loads_scope.average(:estimated_distance),
      average_rate: loads_scope.average(:total_rate),
      total_value: loads_scope.sum(:total_rate),
      match_rate: total_loads > 0 ? (loads_scope.joins(:active_match).count.to_f / total_loads * 100).round(2) : 0,
      completion_rate: total_loads > 0 ? (loads_scope.where(status: 'delivered').count.to_f / total_loads * 100).round(2) : 0,
      daily_breakdown: loads_scope.group('DATE(created_at)').count
    }
  end

  def calculate_route_efficiency(routes_scope)
    total_routes = routes_scope.count
    return {} if total_routes == 0
    
    {
      total_routes: total_routes,
      average_distance: routes_scope.average(:distance_miles),
      average_duration: routes_scope.average(:estimated_duration),
      average_fuel_cost: routes_scope.average(:fuel_cost),
      average_total_cost: routes_scope.average(:total_cost),
      efficiency_scores: {
        fuel_efficiency: routes_scope.map(&:fuel_efficiency_score).compact.sum / routes_scope.count,
        route_quality: routes_scope.map(&:route_quality_score).compact.sum / routes_scope.count,
        environmental_impact: routes_scope.map(&:environmental_impact_score).compact.sum / routes_scope.count
      },
      optimization_breakdown: routes_scope.group(:optimization_type).count,
      cost_savings: calculate_route_cost_savings(routes_scope)
    }
  end

  def calculate_market_trends
    {
      load_volume: {
        last_30_days: Load.where('created_at >= ?', 30.days.ago).count,
        previous_30_days: Load.where('created_at >= ? AND created_at < ?', 60.days.ago, 30.days.ago).count
      },
      average_rates: {
        current: Load.where('created_at >= ?', 30.days.ago).average(:total_rate),
        previous: Load.where('created_at >= ? AND created_at < ?', 60.days.ago, 30.days.ago).average(:total_rate)
      },
      popular_lanes: calculate_popular_lanes,
      equipment_demand: Load.where('created_at >= ?', 30.days.ago).group(:equipment_type).count,
      seasonal_trends: calculate_seasonal_trends
    }
  end

  def shipper_financial_summary
    shipper = current_user.shipper_profile
    loads = shipper.loads.where('created_at >= ?', 30.days.ago)
    
    render json: {
      financial_summary: {
        period: 'Last 30 Days',
        total_spent: loads.sum(:total_rate),
        average_per_load: loads.average(:total_rate),
        cost_breakdown: {
          base_rate: loads.sum(:rate),
          fuel_surcharge: loads.sum(:fuel_surcharge),
          accessorial_charges: loads.sum(:accessorial_charges)
        },
        savings_opportunities: identify_shipper_savings(loads)
      }
    }
  end

  def carrier_financial_summary
    carrier = current_user.carrier_profile
    matches = carrier.matches.where(status: 'accepted').where('created_at >= ?', 30.days.ago)
    
    render json: {
      financial_summary: {
        period: 'Last 30 Days',
        total_revenue: matches.sum(:rate_accepted),
        average_per_load: matches.average(:rate_accepted),
        estimated_costs: calculate_carrier_costs(matches),
        profit_margin: calculate_carrier_profit_margin(matches),
        growth_opportunities: identify_carrier_opportunities(carrier)
      }
    }
  end

  def admin_financial_summary
    render json: {
      financial_summary: {
        period: 'Last 30 Days',
        platform_revenue: calculate_platform_revenue,
        transaction_volume: Load.where('created_at >= ?', 30.days.ago).sum(:total_rate),
        revenue_growth: calculate_revenue_growth,
        top_customers: identify_top_customers,
        market_share: calculate_market_share
      }
    }
  end

  # Helper methods for calculations
  def calculate_average_rate_per_mile(loads)
    total_rate = loads.sum(:total_rate)
    total_distance = loads.sum(:estimated_distance)
    return 0 if total_distance.nil? || total_distance.zero?
    
    (total_rate / total_distance).round(2)
  end

  def calculate_cost_savings(loads)
    # This would compare to market rates
    # For now, return a placeholder
    loads.sum(:total_rate) * 0.05
  end

  def calculate_average_time_to_match(shipper)
    matched_loads = shipper.loads.joins(:active_match)
    return 0 if matched_loads.empty?
    
    total_time = matched_loads.sum do |load|
      match = load.active_match
      next 0 unless match.accepted_at.present? && load.posted_at.present?
      
      (match.accepted_at - load.posted_at) / 1.hour
    end
    
    (total_time / matched_loads.count).round(2)
  end

  def calculate_on_time_delivery_rate(loads)
    delivered_loads = loads.where(status: 'delivered')
    return 0 if delivered_loads.empty?
    
    # This would compare actual vs scheduled delivery dates
    # For now, return a placeholder
    85.5
  end

  def calculate_average_carrier_rating(loads)
    ratings = loads.joins(:assigned_carrier).pluck('carriers.average_rating').compact
    return 0 if ratings.empty?
    
    (ratings.sum / ratings.count).round(2)
  end

  def load_summary(load)
    {
      id: load.id,
      reference_number: load.reference_number,
      status: load.status,
      pickup_city: load.pickup_city,
      delivery_city: load.delivery_city,
      rate: load.total_rate
    }
  end

  def match_summary(match)
    {
      id: match.id,
      load_reference: match.load.reference_number,
      status: match.status,
      rate: match.rate_accepted,
      created_at: match.created_at
    }
  end

  def shipment_summary(shipment)
    {
      id: shipment.id,
      reference_number: shipment.reference_number,
      status: shipment.status,
      pickup_location: shipment.match.load.pickup_city,
      delivery_location: shipment.match.load.delivery_city
    }
  end

  # Additional placeholder methods for complex calculations
  def calculate_total_miles_driven(matches)
    matches.joins(:route).sum(:distance_miles) || 0
  end

  def calculate_fuel_efficiency(matches)
    # Placeholder calculation
    6.5
  end

  def calculate_fleet_utilization(carrier)
    # Placeholder calculation
    75.2
  end

  def calculate_driver_miles(matches)
    calculate_total_miles_driven(matches)
  end

  def calculate_driver_hours(matches)
    matches.joins(:route).sum(:estimated_duration) / 60.0 || 0
  end

  def calculate_driver_on_time_percentage(driver)
    driver.on_time_percentage || 90.0
  end

  def calculate_driver_fuel_efficiency(driver)
    6.8
  end

  def current_load_info(driver)
    # Get current active shipment for driver
    carrier = driver.carrier
    active_shipment = carrier.shipments.where(status: ['picked_up', 'in_transit']).first
    
    return nil unless active_shipment
    
    {
      shipment_id: active_shipment.id,
      load_reference: active_shipment.match.load.reference_number,
      status: active_shipment.status,
      destination: active_shipment.match.load.delivery_city,
      estimated_delivery: active_shipment.estimated_delivery_date
    }
  end

  def calculate_platform_revenue
    # Placeholder - would calculate commission/fees
    Match.where(status: 'accepted').sum(:rate_accepted) * 0.05
  end

  def calculate_system_average_match_time
    24.5
  end

  def calculate_platform_utilization
    78.9
  end

  def calculate_average_system_rating
    4.2
  end

  def calculate_popular_lanes
    Load.where('created_at >= ?', 30.days.ago)
        .group(:pickup_state, :delivery_state)
        .count
        .sort_by { |_, count| -count }
        .first(10)
        .map { |(pickup, delivery), count| { lane: "#{pickup} → #{delivery}", volume: count } }
  end

  def calculate_seasonal_trends
    # Placeholder for seasonal analysis
    { trend: 'increasing', seasonality: 'moderate' }
  end

  def calculate_route_cost_savings(routes_scope)
    # Placeholder calculation
    routes_scope.sum(:total_cost) * 0.08
  end

  def identify_shipper_savings(loads)
    ['Consider bulk shipping discounts', 'Optimize pickup/delivery scheduling']
  end

  def calculate_carrier_costs(matches)
    matches.sum(:rate_accepted) * 0.7  # Assume 70% cost ratio
  end

  def calculate_carrier_profit_margin(matches)
    30.0  # Placeholder percentage
  end

  def identify_carrier_opportunities(carrier)
    ['Expand service area to high-demand lanes', 'Consider additional equipment types']
  end

  def calculate_revenue_growth
    15.2  # Placeholder percentage
  end

  def identify_top_customers
    User.joins(:shipper_profile)
        .joins('JOIN loads ON loads.shipper_id = shippers.id')
        .where('loads.created_at >= ?', 30.days.ago)
        .group('users.id, users.email')
        .order('SUM(loads.total_rate) DESC')
        .limit(5)
        .pluck('users.email, SUM(loads.total_rate)')
        .map { |email, total| { email: email, total_spend: total } }
  end

  def calculate_market_share
    # Placeholder calculation
    { market_share: 12.5, position: 3 }
  end
end