class LoadCreationService
  attr_reader :load, :errors

  def initialize(user, load_params)
    @user = user
    @load_params = load_params
    @errors = []
  end

  def create
    return error_response(['User must be a shipper']) unless @user.shipper?
    
    ActiveRecord::Base.transaction do
      @load = @user.shipper_profile.loads.build(@load_params)
      
      if @load.save
        # Post-creation processing
        process_load_requirements if @load_params[:requirements].present?
        process_cargo_details if @load_params[:cargo_details].present?
        schedule_matching_job
        send_notifications
        
        success_response
      else
        @errors = @load.errors.full_messages
        error_response(@errors)
      end
    end
  rescue StandardError => e
    Rails.logger.error "Load creation failed: #{e.message}"
    @errors = ["Load creation failed: #{e.message}"]
    error_response(@errors)
  end

  private

  def process_load_requirements
    requirements_data = @load_params[:requirements]
    
    requirements_data.each do |req_data|
      @load.load_requirements.create!(
        requirement_type: req_data[:requirement_type],
        requirement_value: req_data[:requirement_value],
        is_mandatory: req_data[:is_mandatory] || true,
        description: req_data[:description]
      )
    end
  end

  def process_cargo_details
    cargo_data = @load_params[:cargo_details]
    
    cargo_data.each do |cargo_item|
      @load.cargo_details.create!(
        item_name: cargo_item[:item_name],
        item_description: cargo_item[:item_description],
        quantity: cargo_item[:quantity],
        unit_type: cargo_item[:unit_type],
        weight_per_unit: cargo_item[:weight_per_unit],
        dimensions: cargo_item[:dimensions],
        value: cargo_item[:value],
        commodity_class: cargo_item[:commodity_class],
        packaging_type: cargo_item[:packaging_type],
        special_handling: cargo_item[:special_handling]
      )
    end
  end

  def schedule_matching_job
    return unless @load.available_for_matching?
    
    # Schedule background job to find potential matches
    CreateMatchesJob.perform_later(@load.id)
  end

  def send_notifications
    # Send confirmation notification to shipper
    # NotifyLoadCreatedJob.perform_later(@load.id)
    
    # Send alerts to relevant carriers
    # NotifyCarriersOfNewLoadJob.perform_later(@load.id)
  end

  def success_response
    {
      success: true,
      load: @load,
      message: 'Load created successfully'
    }
  end

  def error_response(errors)
    {
      success: false,
      errors: errors,
      load: @load
    }
  end
end