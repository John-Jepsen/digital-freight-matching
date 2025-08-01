class NotifyCarrierJob < ApplicationJob
  queue_as :default

  def perform(match_id)
    match = Match.find(match_id)
    carrier = match.carrier
    load = match.load
    
    # In a real application, this would send email, SMS, or push notifications
    # For now, we'll just log the notification
    Rails.logger.info "Notifying carrier #{carrier.company_name} about new load opportunity: #{load.reference_number}"
    
    # Example notification payload
    notification_data = {
      type: 'new_load_opportunity',
      match_id: match.id,
      load_id: load.id,
      load_reference: load.reference_number,
      pickup_city: load.pickup_city,
      pickup_state: load.pickup_state,
      delivery_city: load.delivery_city,
      delivery_state: load.delivery_state,
      rate: load.total_rate,
      match_score: match.match_score,
      distance_to_pickup: match.distance_to_pickup
    }
    
    # TODO: Integrate with notification service (email, SMS, push notifications)
    # EmailService.send_load_notification(carrier.user.email, notification_data)
    # SmsService.send_load_notification(carrier.phone, notification_data)
    # PushNotificationService.send_to_user(carrier.user_id, notification_data)
    
  rescue ActiveRecord::RecordNotFound
    Rails.logger.error "Match not found: #{match_id}"
  rescue => e
    Rails.logger.error "Error notifying carrier for match #{match_id}: #{e.message}"
    raise e
  end
end