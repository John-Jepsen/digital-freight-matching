Rails.application.routes.draw do
  # Health check endpoint
  get "up" => "rails/health#show", as: :rails_health_check

  # Defines the root path route ("/")
  root "application#health"

  # API routes
  namespace :api do
    namespace :v1 do
      # Health check
      get 'health', to: 'health#show'
      
      # Authentication routes
      namespace :auth do
        post 'register', to: 'auth#register'
        post 'login', to: 'auth#login'
        delete 'logout', to: 'auth#logout'
        get 'me', to: 'auth#me'
        post 'refresh', to: 'auth#refresh'
        post 'forgot_password', to: 'auth#forgot_password'
        post 'reset_password', to: 'auth#reset_password'
      end
      
      # User management
      resources :users do
        collection do
          get :profile
          put :update_profile
          post :change_password
        end
        member do
          post :activate
          post :deactivate
          post :suspend
        end
      end
      
      # Load management
      resources :loads do
        collection do
          get :search
        end
        member do
          post :book
          post :complete
          post :cancel
        end
      end
      
      # Carrier management
      resources :carriers do
        member do
          get :available_loads
          post :accept_load
          post :update_location
        end
      end
      
      # Matching endpoints
      namespace :matching do
        post :find_carriers_for_load
        post :find_loads_for_carrier
        get :recommendations
      end
      
      # Route optimization
      namespace :routes do
        post :optimize
        get :calculate_distance
        get :calculate_cost
      end
      
      # Real-time tracking
      namespace :tracking do
        resources :shipments, only: [:show, :update] do
          member do
            get :current_location
            get :status_history
          end
        end
      end
      
      # Analytics
      namespace :analytics do
        get :dashboard
        get :carrier_performance
        get :load_metrics
        get :route_efficiency
      end
    end
  end

  # WebSocket connections for real-time features
  mount ActionCable.server => '/cable'
end
