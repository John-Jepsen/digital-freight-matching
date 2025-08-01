class Api::V1::TrackingController < ApplicationController
  before_action :authenticate_user!

  # GET /api/v1/tracking/shipments/:id
  def show
    @shipment = Shipment.find(params[:id])
    authorize_shipment_access!(@shipment)

    render json: {
      shipment: detailed_shipment_response(@shipment),
      tracking_events: @shipment.tracking_events.chronological.map { |event| tracking_event_response(event) },
      current_location: current_location_response(@shipment),
      status_summary: status_summary_response(@shipment)
    }

  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Shipment not found' }, status: :not_found
  end

  # PUT /api/v1/tracking/shipments/:id
  def update
    @shipment = Shipment.find(params[:id])
    authorize_shipment_update!(@shipment)

    # Create tracking event for status update
    event_params = tracking_event_params
    event_params[:shipment] = @shipment
    event_params[:occurred_at] ||= Time.current
    event_params[:source] = determine_event_source
    event_params[:reported_by] = current_user.email

    tracking_event = TrackingEvent.new(event_params)

    if tracking_event.save
      render json: {
        message: 'Tracking updated successfully',
        shipment: detailed_shipment_response(@shipment.reload),
        tracking_event: tracking_event_response(tracking_event)
      }
    else
      render json: {
        error: 'Failed to update tracking',
        details: tracking_event.errors.full_messages
      }, status: :unprocessable_entity
    end

  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Shipment not found' }, status: :not_found
  end

  # GET /api/v1/tracking/shipments/:id/current_location
  def current_location
    @shipment = Shipment.find(params[:id])
    authorize_shipment_access!(@shipment)

    latest_event = TrackingEvent.latest_location_for_shipment(@shipment)
    
    if latest_event
      render json: {
        shipment_id: @shipment.id,
        current_location: tracking_event_location_response(latest_event),
        last_updated: latest_event.occurred_at,
        status: @shipment.status
      }
    else
      render json: {
        shipment_id: @shipment.id,
        current_location: nil,
        message: 'No location data available'
      }
    end

  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Shipment not found' }, status: :not_found
  end

  # GET /api/v1/tracking/shipments/:id/status_history
  def status_history
    @shipment = Shipment.find(params[:id])
    authorize_shipment_access!(@shipment)

    milestone_events = @shipment.tracking_events.milestones.chronological
    
    render json: {
      shipment_id: @shipment.id,
      status_history: milestone_events.map { |event| status_history_response(event) },
      timeline: generate_timeline(@shipment)
    }

  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Shipment not found' }, status: :not_found
  end

  # POST /api/v1/tracking/shipments/:id/events
  def create_event
    @shipment = Shipment.find(params[:id])
    authorize_shipment_update!(@shipment)

    event_params = tracking_event_params
    event_params[:shipment] = @shipment
    event_params[:occurred_at] ||= Time.current
    event_params[:source] = determine_event_source
    event_params[:reported_by] = current_user.email

    # Set vehicle and driver if current user is a driver
    if current_user.driver?
      event_params[:driver] = current_user.driver_profile
      event_params[:vehicle] = current_user.driver_profile.current_vehicle
    end

    tracking_event = TrackingEvent.new(event_params)

    if tracking_event.save
      render json: {
        message: 'Tracking event created successfully',
        tracking_event: tracking_event_response(tracking_event)
      }, status: :created
    else
      render json: {
        error: 'Failed to create tracking event',
        details: tracking_event.errors.full_messages
      }, status: :unprocessable_entity
    end

  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Shipment not found' }, status: :not_found
  end

  # GET /api/v1/tracking/shipments/:id/alerts
  def alerts
    @shipment = Shipment.find(params[:id])
    authorize_shipment_access!(@shipment)

    alert_events = @shipment.tracking_events.alerts.reverse_chronological.limit(50)
    
    render json: {
      shipment_id: @shipment.id,
      alerts: alert_events.map { |event| alert_response(event) },
      alert_summary: {
        total_alerts: alert_events.count,
        critical_alerts: alert_events.select(&:is_negative_event?).count,
        latest_alert: alert_events.first&.occurred_at
      }
    }

  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Shipment not found' }, status: :not_found
  end

  private

  def authorize_shipment_access!(shipment)
    case current_user.user_type
    when 'admin'
      return # Admins can access all shipments
    when 'shipper'
      return if shipment.match.load.shipper.user == current_user
    when 'carrier'
      return if shipment.match.carrier.user == current_user
    when 'driver'
      carrier = current_user.driver_profile&.carrier
      return if carrier && shipment.match.carrier == carrier
    end
    
    render json: { error: 'Access denied' }, status: :forbidden
  end

  def authorize_shipment_update!(shipment)
    case current_user.user_type
    when 'admin'
      return # Admins can update all shipments
    when 'carrier'
      return if shipment.match.carrier.user == current_user
    when 'driver'
      carrier = current_user.driver_profile&.carrier
      return if carrier && shipment.match.carrier == carrier
    end
    
    render json: { error: 'Update access denied' }, status: :forbidden
  end

  def determine_event_source
    case current_user.user_type
    when 'driver'
      'driver_input'
    when 'carrier', 'shipper'
      'manual'
    when 'admin'
      'manual'
    else
      'api'
    end
  end

  def tracking_event_params
    params.require(:tracking_event).permit(
      :event_type, :status, :location, :latitude, :longitude,
      :description, :notes, :occurred_at, :temperature, :humidity,
      :external_id, :metadata
    )
  end

  def detailed_shipment_response(shipment)
    {
      id: shipment.id,
      reference_number: shipment.reference_number,
      status: shipment.status,
      load: {
        id: shipment.match.load.id,
        reference_number: shipment.match.load.reference_number,
        pickup_location: shipment.match.load.pickup_full_address,
        delivery_location: shipment.match.load.delivery_full_address
      },
      carrier: {
        id: shipment.match.carrier.id,
        company_name: shipment.match.carrier.company_name
      },
      created_at: shipment.created_at,
      updated_at: shipment.updated_at
    }
  end

  def tracking_event_response(event)
    {
      id: event.id,
      event_type: event.event_type,
      status: event.status,
      location: event.display_location,
      coordinates: event.coordinates,
      description: event.formatted_event_description,
      notes: event.notes,
      occurred_at: event.occurred_at,
      time_since_occurred: event.time_since_occurred,
      source: event.source,
      reported_by: event.reported_by,
      is_milestone: event.is_milestone,
      is_alert: event.is_alert?,
      severity_level: event.severity_level,
      temperature: event.temperature,
      humidity: event.humidity,
      metadata: event.metadata_hash
    }
  end

  def current_location_response(shipment)
    latest_event = TrackingEvent.latest_location_for_shipment(shipment)
    return nil unless latest_event
    
    tracking_event_location_response(latest_event)
  end

  def tracking_event_location_response(event)
    {
      latitude: event.latitude,
      longitude: event.longitude,
      location: event.display_location,
      timestamp: event.occurred_at,
      source: event.source
    }
  end

  def status_summary_response(shipment)
    events = shipment.tracking_events
    
    {
      current_status: shipment.status,
      total_events: events.count,
      milestone_events: events.milestones.count,
      alert_events: events.alerts.count,
      last_update: events.maximum(:occurred_at),
      estimated_delivery: shipment.estimated_delivery_date
    }
  end

  def status_history_response(event)
    {
      event_type: event.event_type,
      status: event.status,
      occurred_at: event.occurred_at,
      location: event.display_location,
      description: event.formatted_event_description,
      is_positive: event.is_positive_milestone?,
      severity_level: event.severity_level
    }
  end

  def alert_response(event)
    {
      id: event.id,
      event_type: event.event_type,
      severity_level: event.severity_level,
      description: event.formatted_event_description,
      location: event.display_location,
      occurred_at: event.occurred_at,
      is_resolved: event.completed?,
      metadata: event.metadata_hash
    }
  end

  def generate_timeline(shipment)
    load = shipment.match.load
    
    timeline = [
      {
        event: 'pickup_scheduled',
        target_date: load.pickup_date,
        status: shipment.tracking_events.pickup_completed.any? ? 'completed' : 'pending'
      },
      {
        event: 'in_transit',
        target_date: load.pickup_date + 1.day,
        status: shipment.tracking_events.in_transit.any? ? 'completed' : 'pending'
      },
      {
        event: 'delivery_scheduled',
        target_date: load.delivery_date,
        status: shipment.tracking_events.delivery_completed.any? ? 'completed' : 'pending'
      }
    ]
    
    timeline
  end
end