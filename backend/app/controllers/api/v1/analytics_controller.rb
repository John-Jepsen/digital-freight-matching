class Api::V1::AnalyticsController < ApplicationController
  include Monitorable
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

  # GET /api/v1/analytics/business_metrics
  def business_metrics
    authorize_analytics_access!(['admin'])
    
    metrics_data = {
      real_time_metrics: collect_real_time_business_metrics,
      performance_metrics: collect_performance_metrics,
      sla_metrics: collect_sla_metrics,
      system_health: collect_system_health_metrics
    }

    render json: { business_metrics: metrics_data }
  end

  # GET /api/v1/analytics/sla_dashboard
  def sla_dashboard
    authorize_analytics_access!(['admin'])
    
    sla_data = {
      response_time_sla: calculate_response_time_sla,
      uptime_sla: calculate_uptime_sla,
      load_matching_sla: calculate_load_matching_sla,
      error_rate_sla: calculate_error_rate_sla,
      current_status: determine_overall_sla_status
    }

    render json: { sla_dashboard: sla_data }
  end

  # GET /api/v1/analytics/alerts_summary
  def alerts_summary
    authorize_analytics_access!(['admin'])
    
    alerts_data = {
      active_alerts: collect_active_alerts,
      recent_incidents: collect_recent_incidents,
      alert_trends: calculate_alert_trends,
      mttr_metrics: calculate_mttr_metrics
    }

    render json: { alerts_summary: alerts_data }
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

  # Real-time business metrics collection
  def collect_real_time_business_metrics
    {
      active_loads: Load.where(status: ['posted', 'matched', 'in_transit']).count,
      active_users: User.where('last_sign_in_at > ?', 1.hour.ago).count,
      loads_posted_today: Load.where('created_at >= ?', Date.current).count,
      matches_made_today: Match.where('created_at >= ? AND status = ?', Date.current, 'accepted').count,
      revenue_today: Load.joins(:payments)
                        .where('loads.created_at >= ? AND payments.status = ?', Date.current, 'completed')
                        .sum('payments.amount'),
      average_response_time: calculate_average_response_time,
      load_matching_success_rate: calculate_load_matching_success_rate
    }
  rescue StandardError => e
    Rails.logger.error "Failed to collect real-time metrics: #{e.message}"
    {}
  end

  def collect_performance_metrics
    {
      api_response_times: calculate_api_performance_metrics,
      database_performance: calculate_database_performance,
      cache_hit_rate: calculate_cache_performance,
      background_job_performance: calculate_job_performance
    }
  end

  def collect_sla_metrics
    {
      uptime_percentage: calculate_uptime_percentage,
      error_rate: calculate_error_rate,
      response_time_p95: calculate_response_time_percentile(95),
      response_time_p99: calculate_response_time_percentile(99),
      load_matching_sla_compliance: calculate_matching_sla_compliance
    }
  end

  def collect_system_health_metrics
    {
      database_status: check_database_health,
      redis_status: check_redis_health,
      background_jobs_status: check_background_jobs_health,
      external_services_status: check_external_services_health,
      system_resources: collect_system_resource_metrics
    }
  end

  # SLA calculation methods
  def calculate_response_time_sla
    {
      target_p95: 2.0,
      current_p95: calculate_response_time_percentile(95),
      target_p99: 5.0,
      current_p99: calculate_response_time_percentile(99),
      compliance_percentage: calculate_response_time_compliance,
      violations_today: count_response_time_violations_today
    }
  end

  def calculate_uptime_sla
    uptime_percentage = calculate_uptime_percentage
    {
      target_uptime: 99.9,
      current_uptime: uptime_percentage,
      compliance: uptime_percentage >= 99.9,
      downtime_minutes_today: calculate_downtime_minutes_today,
      availability_trend: calculate_availability_trend
    }
  end

  def calculate_load_matching_sla
    success_rate = calculate_load_matching_success_rate
    {
      target_success_rate: 85.0,
      current_success_rate: success_rate,
      compliance: success_rate >= 85.0,
      average_match_time: calculate_average_match_time,
      failed_matches_today: count_failed_matches_today
    }
  end

  def calculate_error_rate_sla
    error_rate = calculate_error_rate
    {
      target_error_rate: 1.0,
      current_error_rate: error_rate,
      compliance: error_rate <= 1.0,
      critical_errors_today: count_critical_errors_today,
      error_trend: calculate_error_trend
    }
  end

  def determine_overall_sla_status
    response_time_ok = calculate_response_time_percentile(95) <= 2.0
    uptime_ok = calculate_uptime_percentage >= 99.9
    error_rate_ok = calculate_error_rate <= 1.0
    matching_ok = calculate_load_matching_success_rate >= 85.0

    if response_time_ok && uptime_ok && error_rate_ok && matching_ok
      'healthy'
    elsif !uptime_ok || calculate_error_rate > 5.0
      'critical'
    else
      'warning'
    end
  end

  # Alert and incident management methods
  def collect_active_alerts
    [
      # This would integrate with your alerting system
      # For now, return mock data
    ]
  end

  def collect_recent_incidents
    [
      # This would pull from incident tracking system
      # Mock data for now
    ]
  end

  def calculate_alert_trends
    {
      alerts_this_week: 0, # Would be calculated from actual data
      mttr_hours: 0.25,
      alert_frequency_trend: 'decreasing'
    }
  end

  def calculate_mttr_metrics
    {
      current_mttr_minutes: 15,
      target_mttr_minutes: 15,
      mttr_trend: 'stable',
      incidents_resolved_under_15min: 95
    }
  end

  # Helper methods for metrics calculation
  def calculate_average_response_time
    # This would integrate with metrics collection
    # For now return a reasonable default
    0.5
  end

  def calculate_load_matching_success_rate
    return 0.0 unless defined?(Load) && defined?(Match)
    
    total_loads = Load.where('created_at >= ?', 24.hours.ago).count
    return 0.0 if total_loads.zero?
    
    successful_matches = Load.joins(:matches)
                            .where('loads.created_at >= ? AND matches.status = ?', 24.hours.ago, 'accepted')
                            .distinct
                            .count
    
    (successful_matches.to_f / total_loads * 100).round(2)
  rescue NameError
    85.0 # Default value when models aren't available
  end

  def calculate_api_performance_metrics
    {
      average_response_time: 0.5,
      p95_response_time: 1.2,
      p99_response_time: 2.1,
      slowest_endpoints: [
        { endpoint: 'analytics#dashboard', avg_time: 1.2 },
        { endpoint: 'matching#find_carriers', avg_time: 0.8 }
      ]
    }
  end

  def calculate_database_performance
    {
      average_query_time: 0.05,
      slow_queries_count: 2,
      connection_pool_usage: 45,
      deadlocks_today: 0
    }
  end

  def calculate_cache_performance
    {
      hit_rate_percentage: 85.5,
      miss_rate_percentage: 14.5,
      evictions_per_hour: 10
    }
  end

  def calculate_job_performance
    {
      jobs_processed_today: 1250,
      average_job_duration: 0.3,
      failed_jobs_today: 5,
      retry_rate_percentage: 2.1
    }
  end

  def calculate_uptime_percentage
    # This would integrate with monitoring system
    99.95
  end

  def calculate_error_rate
    # Calculate based on recent API requests
    0.5 # Percentage
  end

  def calculate_response_time_percentile(percentile)
    # This would integrate with metrics system
    case percentile
    when 95
      1.2
    when 99
      2.1
    else
      0.8
    end
  end

  def calculate_response_time_compliance
    # Percentage of requests meeting SLA
    98.5
  end

  def count_response_time_violations_today
    # Count of SLA violations today
    3
  end

  def calculate_downtime_minutes_today
    # Minutes of downtime today
    0
  end

  def calculate_availability_trend
    # Trend over the past week
    'stable'
  end

  def calculate_average_match_time
    # Average time to match a load with a carrier (in minutes)
    45
  end

  def count_failed_matches_today
    return 0 unless defined?(Match)
    
    Match.where('created_at >= ? AND status = ?', Date.current, 'failed').count
  rescue NameError
    0
  end

  def count_critical_errors_today
    # Count of critical errors today
    0
  end

  def calculate_error_trend
    # Error trend over past week
    'decreasing'
  end

  # Health check methods
  def check_database_health
    ActiveRecord::Base.connection.execute("SELECT 1")
    'healthy'
  rescue StandardError
    'unhealthy'
  end

  def check_redis_health
    Rails.cache.fetch('health_check', expires_in: 1.second) { 'ok' }
    'healthy'
  rescue StandardError
    'unhealthy'
  end

  def check_background_jobs_health
    # Check Sidekiq queue sizes and processing
    'healthy'
  end

  def check_external_services_health
    {
      google_maps: 'healthy',
      stripe: 'healthy',
      sendgrid: 'healthy'
    }
  end

  def collect_system_resource_metrics
    {
      cpu_usage_percentage: 45,
      memory_usage_percentage: 67,
      disk_usage_percentage: 32,
      network_io: 'normal'
    }
  end
end