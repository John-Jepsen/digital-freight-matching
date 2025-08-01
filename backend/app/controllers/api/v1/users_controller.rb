class Api::V1::UsersController < ApplicationController
  before_action :authenticate_user!
  before_action :set_user, only: [:show, :update, :destroy]
  before_action :authorize_user!, only: [:show, :update, :destroy]

  # GET /api/v1/users
  def index
    authorize_admin!
    
    @users = User.includes(:shipper_profile, :carrier_profile, :driver_profile)
                 .page(params[:page])
                 .per(params[:per_page] || 25)

    # Apply filters
    @users = @users.where(user_type: params[:user_type]) if params[:user_type].present?
    @users = @users.where(status: params[:status]) if params[:status].present?
    @users = @users.where('first_name ILIKE ? OR last_name ILIKE ?', "%#{params[:search]}%", "%#{params[:search]}%") if params[:search].present?

    render json: {
      users: @users.map { |user| user_response(user) },
      meta: {
        current_page: @users.current_page,
        total_pages: @users.total_pages,
        total_count: @users.total_count,
        per_page: @users.limit_value
      }
    }
  end

  # GET /api/v1/users/:id
  def show
    render json: {
      user: detailed_user_response(@user)
    }
  end

  # PUT/PATCH /api/v1/users/:id
  def update
    if @user.update(user_update_params)
      render json: {
        message: 'User updated successfully',
        user: detailed_user_response(@user)
      }
    else
      render json: {
        error: 'Update failed',
        details: @user.errors.full_messages
      }, status: :unprocessable_entity
    end
  end

  # DELETE /api/v1/users/:id
  def destroy
    authorize_admin_or_self!
    
    if @user.destroy
      render json: {
        message: 'User deleted successfully'
      }
    else
      render json: {
        error: 'Delete failed',
        details: @user.errors.full_messages
      }, status: :unprocessable_entity
    end
  end

  # POST /api/v1/users/:id/activate
  def activate
    authorize_admin!
    set_user
    
    if @user.update(status: 'active')
      render json: {
        message: 'User activated successfully',
        user: user_response(@user)
      }
    else
      render json: {
        error: 'Activation failed',
        details: @user.errors.full_messages
      }, status: :unprocessable_entity
    end
  end

  # POST /api/v1/users/:id/deactivate
  def deactivate
    authorize_admin!
    set_user
    
    if @user.update(status: 'inactive')
      render json: {
        message: 'User deactivated successfully',
        user: user_response(@user)
      }
    else
      render json: {
        error: 'Deactivation failed',
        details: @user.errors.full_messages
      }, status: :unprocessable_entity
    end
  end

  # POST /api/v1/users/:id/suspend
  def suspend
    authorize_admin!
    set_user
    
    if @user.update(status: 'suspended')
      render json: {
        message: 'User suspended successfully',
        user: user_response(@user)
      }
    else
      render json: {
        error: 'Suspension failed',
        details: @user.errors.full_messages
      }, status: :unprocessable_entity
    end
  end

  # GET /api/v1/users/profile
  def profile
    render json: {
      user: detailed_user_response(current_user)
    }
  end

  # PUT /api/v1/users/profile
  def update_profile
    if current_user.update(profile_update_params)
      render json: {
        message: 'Profile updated successfully',
        user: detailed_user_response(current_user)
      }
    else
      render json: {
        error: 'Profile update failed',
        details: current_user.errors.full_messages
      }, status: :unprocessable_entity
    end
  end

  # POST /api/v1/users/change_password
  def change_password
    if current_user.valid_password?(params[:current_password])
      if current_user.update(password: params[:new_password], password_confirmation: params[:password_confirmation])
        render json: {
          message: 'Password changed successfully'
        }
      else
        render json: {
          error: 'Password change failed',
          details: current_user.errors.full_messages
        }, status: :unprocessable_entity
      end
    else
      render json: {
        error: 'Current password is incorrect'
      }, status: :unauthorized
    end
  end

  private

  def set_user
    @user = User.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'User not found' }, status: :not_found
  end

  def authorize_user!
    return if current_user.admin? || current_user == @user
    
    render json: { error: 'Access denied' }, status: :forbidden
  end

  def authorize_admin!
    return if current_user.admin?
    
    render json: { error: 'Admin access required' }, status: :forbidden
  end

  def authorize_admin_or_self!
    return if current_user.admin? || current_user == @user
    
    render json: { error: 'Access denied' }, status: :forbidden
  end

  def user_update_params
    allowed_params = [:first_name, :last_name, :phone]
    allowed_params += [:email, :user_type, :status] if current_user.admin?
    
    params.require(:user).permit(allowed_params)
  end

  def profile_update_params
    params.require(:user).permit(:first_name, :last_name, :phone)
  end

  def user_response(user)
    {
      id: user.id,
      email: user.email,
      first_name: user.first_name,
      last_name: user.last_name,
      full_name: user.full_name,
      phone: user.phone,
      user_type: user.user_type,
      status: user.status,
      average_rating: user.average_rating,
      total_ratings: user.total_ratings,
      created_at: user.created_at
    }
  end

  def detailed_user_response(user)
    response = user_response(user)
    
    # Add profile information
    if user.profile.present?
      response[:profile] = case user.user_type
      when 'shipper'
        shipper_profile_response(user.shipper_profile)
      when 'carrier'
        carrier_profile_response(user.carrier_profile)
      when 'driver'
        driver_profile_response(user.driver_profile)
      end
    end
    
    response
  end

  def shipper_profile_response(shipper)
    return nil unless shipper
    
    {
      id: shipper.id,
      company_name: shipper.company_name,
      industry: shipper.industry,
      phone: shipper.phone,
      website: shipper.website,
      verified: shipper.verified?,
      active_loads_count: shipper.active_loads_count,
      completed_loads_count: shipper.completed_loads_count,
      total_shipped_value: shipper.total_shipped_value,
      credit_available: shipper.credit_available
    }
  end

  def carrier_profile_response(carrier)
    return nil unless carrier
    
    {
      id: carrier.id,
      company_name: carrier.company_name,
      mc_number: carrier.mc_number,
      dot_number: carrier.dot_number,
      fleet_size: carrier.fleet_size,
      safety_rating: carrier.safety_rating,
      is_verified: carrier.is_verified,
      is_active: carrier.is_active,
      equipment_types: carrier.equipment_list,
      service_areas: carrier.service_area_list,
      total_completed_loads: carrier.total_completed_loads,
      on_time_percentage: carrier.on_time_percentage,
      safety_score: carrier.safety_score
    }
  end

  def driver_profile_response(driver)
    return nil unless driver
    
    {
      id: driver.id,
      driver_number: driver.driver_number,
      license_number: driver.license_number,
      license_state: driver.license_state,
      cdl_class: driver.cdl_class,
      endorsements: driver.endorsement_list,
      status: driver.status,
      is_hazmat_certified: driver.is_hazmat_certified,
      is_team_driver: driver.is_team_driver,
      compliance_status: driver.compliance_status,
      safety_score: driver.safety_score,
      years_of_experience: driver.years_of_experience
    }
  end
end