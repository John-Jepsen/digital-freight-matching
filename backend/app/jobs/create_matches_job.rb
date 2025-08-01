class CreateMatchesJob < ApplicationJob
  queue_as :default

  def perform(load_id, options = {})
    load = Load.find(load_id)
    return unless load.available_for_matching?

    # Create matches with eligible carriers
    matches = Match.create_for_load(load, options)
    
    Rails.logger.info "Created #{matches.count} matches for load #{load.reference_number}"
    
    # Optionally notify carriers about new load opportunity
    matches.each do |match|
      NotifyCarrierJob.perform_later(match.id) if match.persisted?
    end
    
  rescue ActiveRecord::RecordNotFound
    Rails.logger.error "Load not found: #{load_id}"
  rescue => e
    Rails.logger.error "Error creating matches for load #{load_id}: #{e.message}"
    raise e
  end
end