# Testing Strategy & Quality Assurance

## 🧪 Testing Philosophy

The Digital Freight Matching Platform follows a comprehensive testing strategy that ensures reliability, security, and business logic correctness across all components. Testing is treated as a first-class concern, not an afterthought.

### Testing Pyramid Structure
- **Unit Tests (70%)**: Fast, isolated tests for business logic
- **Integration Tests (20%)**: API endpoints, service interactions
- **End-to-End Tests (10%)**: Critical user workflows

## 🛠️ Backend Testing with RSpec

### Test Configuration
```ruby
# spec/spec_helper.rb
require 'simplecov'
SimpleCov.start 'rails' do
  add_filter '/spec/'
  add_filter '/config/'
  add_group 'Services', 'app/services'
  add_group 'Jobs', 'app/jobs'
  minimum_coverage 85
end

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups
  config.filter_run_when_matching :focus
  config.example_status_persistence_file_path = "spec/examples.txt"
  config.disable_monkey_patching!
  config.warnings = true
  
  if config.files_to_run.one?
    config.default_formatter = "doc"
  end

  config.profile_examples = 10
  config.order = :random
  Kernel.srand config.seed
end

# spec/rails_helper.rb
require 'spec_helper'
ENV['RAILS_ENV'] ||= 'test'
require_relative '../config/environment'

abort("The Rails environment is running in production mode!") if Rails.env.production?

require 'rspec/rails'
require 'factory_bot_rails'
require 'shoulda/matchers'
require 'database_cleaner/active_record'
require 'webmock/rspec'

Dir[Rails.root.join('spec', 'support', '**', '*.rb')].sort.each { |f| require f }

ActiveRecord::Migration.maintain_test_schema!

RSpec.configure do |config|
  config.fixture_path = "#{::Rails.root}/spec/fixtures"
  config.use_transactional_fixtures = false
  config.infer_spec_type_from_file_location!
  config.filter_rails_from_backtrace!
  
  config.include FactoryBot::Syntax::Methods
  config.include AuthenticationHelpers, type: :request
  config.include ApiHelpers, type: :request
  
  # Database cleaning strategy
  config.before(:suite) do
    DatabaseCleaner.clean_with(:truncation)
  end

  config.before(:each) do
    DatabaseCleaner.strategy = :transaction
  end

  config.before(:each, :js => true) do
    DatabaseCleaner.strategy = :truncation
  end

  config.before(:each) do
    DatabaseCleaner.start
  end

  config.after(:each) do
    DatabaseCleaner.clean
  end
end
```

### Model Testing Examples
```ruby
# spec/models/load_spec.rb
RSpec.describe Load, type: :model do
  describe 'associations' do
    it { should belong_to(:shipper).class_name('ShipperProfile') }
    it { should have_many(:matches).dependent(:destroy) }
    it { should have_many(:load_requirements).dependent(:destroy) }
    it { should have_many(:cargo_details).dependent(:destroy) }
    it { should have_one(:shipment).dependent(:destroy) }
  end

  describe 'validations' do
    subject { build(:load) }
    
    it { should validate_presence_of(:pickup_location) }
    it { should validate_presence_of(:delivery_location) }
    it { should validate_presence_of(:pickup_datetime) }
    it { should validate_presence_of(:delivery_datetime) }
    it { should validate_presence_of(:price) }
    it { should validate_numericality_of(:price).is_greater_than(0) }
    it { should validate_numericality_of(:weight).is_greater_than(0).allow_nil }
  end

  describe 'state machine' do
    let(:load) { create(:load) }

    it 'starts in posted state' do
      expect(load).to be_posted
    end

    it 'can transition to matched' do
      expect { load.match_with_carrier! }.to change(load, :status).from('posted').to('matched')
    end

    it 'cannot transition from delivered to matched' do
      load.update!(status: 'delivered')
      expect { load.match_with_carrier! }.to raise_error(AASM::InvalidTransition)
    end
  end

  describe 'business logic' do
    let(:load) { create(:load, :with_coordinates) }

    describe '#distance_miles' do
      it 'calculates distance between pickup and delivery' do
        expect(load.distance_miles).to be > 0
        expect(load.distance_miles).to be_within(10).of(248)  # Atlanta to Savannah
      end

      it 'returns 0 when coordinates are missing' do
        load.update!(pickup_lat: nil, pickup_lng: nil)
        expect(load.distance_miles).to eq(0)
      end
    end

    describe '#price_per_mile' do
      it 'calculates correct price per mile' do
        load.update!(price: 2500, distance_miles: 250)
        expect(load.price_per_mile).to eq(10.0)
      end

      it 'returns 0 when distance is zero' do
        allow(load).to receive(:distance_miles).and_return(0)
        expect(load.price_per_mile).to eq(0)
      end
    end

    describe '#market_rate_comparison' do
      it 'compares against industry average' do
        load.update!(price: 2500)
        allow(load).to receive(:distance_miles).and_return(250)
        
        comparison = load.market_rate_comparison
        expect(comparison[:current_rate]).to eq(10.0)
        expect(comparison[:industry_average]).to eq(1.855)
        expect(comparison[:variance_percentage]).to be > 400
      end
    end

    describe '#estimated_transit_time' do
      it 'calculates reasonable transit time' do
        allow(load).to receive(:distance_miles).and_return(250)
        expect(load.estimated_transit_time).to eq(7.0)  # 5 hours driving + 2 hours loading
      end
    end
  end

  describe 'scopes' do
    let!(:posted_load) { create(:load, status: 'posted') }
    let!(:matched_load) { create(:load, status: 'matched') }
    let!(:urgent_load) { create(:load, pickup_datetime: 12.hours.from_now) }
    let!(:normal_load) { create(:load, pickup_datetime: 3.days.from_now) }

    describe '.available' do
      it 'returns only posted loads' do
        expect(Load.available).to contain_exactly(posted_load)
      end
    end

    describe '.high_priority' do
      it 'returns loads picking up within 24 hours' do
        expect(Load.high_priority).to contain_exactly(urgent_load)
      end
    end

    describe '.price_range' do
      it 'filters loads by price range' do
        cheap_load = create(:load, price: 500)
        expensive_load = create(:load, price: 5000)
        
        expect(Load.price_range(400, 1000)).to contain_exactly(cheap_load)
      end
    end
  end

  describe 'callbacks' do
    it 'geocodes locations after validation' do
      load = build(:load, pickup_location: '123 Main St, Atlanta, GA')
      
      expect(load).to receive(:geocode_locations)
      load.save!
    end

    it 'updates search vector on save' do
      load = create(:load, description: 'Electronics shipment')
      
      expect(load.search_vector).to be_present
      expect(load.search_vector).to include('electron')
    end
  end
end

# spec/models/match_spec.rb
RSpec.describe Match, type: :model do
  describe 'associations' do
    it { should belong_to(:load) }
    it { should belong_to(:carrier).class_name('CarrierProfile') }
    it { should have_one(:route).dependent(:destroy) }
    it { should have_one(:shipment).dependent(:destroy) }
  end

  describe 'validations' do
    subject { build(:match) }
    
    it { should validate_presence_of(:match_score) }
    it { should validate_numericality_of(:match_score).is_in(0..100) }
    it { should validate_uniqueness_of(:carrier_id).scoped_to(:load_id) }
  end

  describe 'state transitions' do
    let(:match) { create(:match) }

    it 'can be accepted by carrier' do
      expect { match.accept! }.to change(match, :status).to('accepted')
      expect(match.accepted_at).to be_present
    end

    it 'creates shipment when accepted' do
      expect { match.accept! }.to change(Shipment, :count).by(1)
    end

    it 'can be rejected by carrier' do
      expect { match.reject! }.to change(match, :status).to('rejected')
    end

    it 'expires after timeout period' do
      match.update!(expires_at: 1.hour.ago)
      expect(match).to be_expired
    end
  end
end
```

### Service Object Testing
```ruby
# spec/services/matching_algorithm_service_spec.rb
RSpec.describe MatchingAlgorithmService, type: :service do
  describe '#call' do
    let(:load) { create(:load, :with_coordinates, pickup_location: 'Atlanta, GA') }
    let(:service) { described_class.new(load, max_distance: 100, min_rating: 0) }

    context 'with available carriers' do
      let!(:close_carrier) { create(:carrier_profile, :with_location, latitude: 33.7490, longitude: -84.3880) }  # Atlanta
      let!(:far_carrier) { create(:carrier_profile, :with_location, latitude: 25.7617, longitude: -80.1918) }   # Miami
      let!(:inactive_carrier) { create(:carrier_profile, :inactive, :with_location, latitude: 33.7490, longitude: -84.3880) }

      before do
        create(:vehicle, carrier: close_carrier, vehicle_type: 'dry_van', status: 'active')
        create(:vehicle, carrier: far_carrier, vehicle_type: 'dry_van', status: 'active')
      end

      it 'returns successful result with matches' do
        result = service.call
        
        expect(result).to be_success
        expect(result.data).to be_present
        expect(result.data.size).to eq(2)  # close and far carrier
      end

      it 'ranks carriers by match score' do
        result = service.call
        matches = result.data
        
        expect(matches.first[:carrier]).to eq(close_carrier)
        expect(matches.first[:score]).to be > matches.last[:score]
      end

      it 'excludes inactive carriers' do
        result = service.call
        carrier_ids = result.data.map { |match| match[:carrier].id }
        
        expect(carrier_ids).not_to include(inactive_carrier.id)
      end

      it 'respects distance limits' do
        service = described_class.new(load, max_distance: 50)
        result = service.call
        
        # Only close carrier should match
        expect(result.data.size).to eq(1)
        expect(result.data.first[:carrier]).to eq(close_carrier)
      end

      it 'calculates score components correctly' do
        result = service.call
        match = result.data.first
        
        expect(match[:components]).to include(:distance, :equipment, :rating, :price, :availability)
        expect(match[:components][:distance]).to be_between(90, 100)  # Close carrier gets high distance score
      end

      it 'provides estimated pickup times' do
        result = service.call
        match = result.data.first
        
        expect(match[:estimated_pickup_time]).to be_present
        expect(match[:estimated_pickup_time]).to be > Time.current
      end
    end

    context 'without available carriers' do
      it 'returns empty matches' do
        result = service.call
        
        expect(result).to be_success
        expect(result.data).to be_empty
      end
    end

    context 'with equipment requirements' do
      let!(:carrier_with_reefer) { create(:carrier_profile, :with_location, latitude: 33.7490, longitude: -84.3880) }
      let!(:carrier_with_dry_van) { create(:carrier_profile, :with_location, latitude: 33.7490, longitude: -84.3880) }

      before do
        create(:vehicle, carrier: carrier_with_reefer, vehicle_type: 'refrigerated')
        create(:vehicle, carrier: carrier_with_dry_van, vehicle_type: 'dry_van')
        create(:load_requirement, load: load, equipment_type: 'refrigerated')
      end

      it 'prioritizes carriers with matching equipment' do
        result = service.call
        matches = result.data

        reefer_match = matches.find { |m| m[:carrier] == carrier_with_reefer }
        dry_van_match = matches.find { |m| m[:carrier] == carrier_with_dry_van }

        expect(reefer_match[:components][:equipment]).to eq(100)
        expect(dry_van_match[:components][:equipment]).to eq(0)
      end
    end

    context 'with already matched carriers' do
      let!(:carrier) { create(:carrier_profile, :with_location) }
      let!(:existing_match) { create(:match, load: load, carrier: carrier) }

      it 'excludes already matched carriers' do
        result = service.call
        carrier_ids = result.data.map { |match| match[:carrier].id }
        
        expect(carrier_ids).not_to include(carrier.id)
      end
    end
  end

  describe '#distance_score' do
    it 'calculates distance score correctly' do
      # Private method testing through public interface
      load = create(:load, :with_coordinates)
      carrier = create(:carrier_profile, :with_location, latitude: 33.7490, longitude: -84.3880)
      service = described_class.new(load, max_distance: 100)

      result = service.call
      match = result.data.first

      expect(match[:components][:distance]).to be_between(0, 100)
    end
  end
end

# spec/services/route_calculation_service_spec.rb
RSpec.describe RouteCalculationService, type: :service do
  let(:service) { described_class.new('Atlanta, GA', 'Savannah, GA') }

  before do
    # Mock Google Maps API responses
    stub_request(:get, /maps.googleapis.com.*directions/)
      .to_return(
        status: 200,
        body: file_fixture('google_maps_directions_response.json').read,
        headers: { 'Content-Type' => 'application/json' }
      )
  end

  describe '#call' do
    it 'returns route calculation data' do
      result = service.call

      expect(result[:distance_miles]).to be_present
      expect(result[:duration_hours]).to be_present
      expect(result[:fuel_cost]).to be_present
      expect(result[:toll_cost]).to be_present
      expect(result[:total_cost]).to be_present
    end

    it 'calculates reasonable costs' do
      result = service.call

      expect(result[:distance_miles]).to be_within(20).of(248)
      expect(result[:duration_hours]).to be_within(1).of(4.2)
      expect(result[:fuel_cost]).to be > 80
      expect(result[:total_cost]).to be > 400
    end
  end

  context 'with Google Maps API error' do
    before do
      stub_request(:get, /maps.googleapis.com.*directions/)
        .to_return(status: 500)
    end

    it 'handles API errors gracefully' do
      expect { service.call }.to raise_error(GoogleMaps::Error)
    end
  end
end
```

### Controller Testing (Request specs)
```ruby
# spec/requests/api/v1/loads_spec.rb
RSpec.describe 'Loads API', type: :request do
  let(:shipper) { create(:user, :shipper) }
  let(:carrier) { create(:user, :carrier) }
  let(:admin) { create(:user, :admin) }

  describe 'POST /api/v1/loads' do
    let(:valid_attributes) do
      {
        load: {
          pickup_location: 'Atlanta, GA',
          delivery_location: 'Savannah, GA',
          pickup_datetime: 2.days.from_now.iso8601,
          delivery_datetime: 3.days.from_now.iso8601,
          weight: 15000,
          price: 2500.00,
          description: 'Electronics shipment'
        }
      }
    end

    context 'as authenticated shipper' do
      before { authenticate_as(shipper) }

      it 'creates a new load' do
        expect {
          post '/api/v1/loads', params: valid_attributes, as: :json
        }.to change(Load, :count).by(1)

        expect(response).to have_http_status(:created)
        expect(json_response['data']['attributes']['status']).to eq('posted')
      end

      it 'triggers matching algorithm job' do
        expect(MatchingJob).to receive(:perform_later)
        
        post '/api/v1/loads', params: valid_attributes, as: :json
      end

      it 'creates audit log entry' do
        expect {
          post '/api/v1/loads', params: valid_attributes, as: :json
        }.to change(AuditLog, :count).by(1)

        audit_log = AuditLog.last
        expect(audit_log.action).to eq('create_load')
        expect(audit_log.user).to eq(shipper)
      end

      context 'with invalid attributes' do
        let(:invalid_attributes) do
          {
            load: {
              pickup_location: '',
              delivery_location: 'Savannah, GA',
              price: -100
            }
          }
        end

        it 'returns validation errors' do
          post '/api/v1/loads', params: invalid_attributes, as: :json

          expect(response).to have_http_status(:unprocessable_entity)
          expect(json_response['errors']).to include('pickup_location', 'price')
        end
      end
    end

    context 'as carrier' do
      before { authenticate_as(carrier) }

      it 'returns forbidden' do
        post '/api/v1/loads', params: valid_attributes, as: :json

        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'without authentication' do
      it 'returns unauthorized' do
        post '/api/v1/loads', params: valid_attributes, as: :json

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'GET /api/v1/loads' do
    let!(:shipper_load) { create(:load, shipper: shipper.shipper_profile) }
    let!(:other_load) { create(:load) }
    let!(:posted_load) { create(:load, status: 'posted') }

    context 'as shipper' do
      before { authenticate_as(shipper) }

      it 'returns only shipper\'s loads' do
        get '/api/v1/loads', as: :json

        expect(response).to have_http_status(:ok)
        load_ids = json_response['data'].map { |load| load['id'].to_i }
        expect(load_ids).to include(shipper_load.id)
        expect(load_ids).not_to include(other_load.id)
      end
    end

    context 'as carrier' do
      before { authenticate_as(carrier) }

      it 'returns posted loads' do
        get '/api/v1/loads', as: :json

        expect(response).to have_http_status(:ok)
        load_ids = json_response['data'].map { |load| load['id'].to_i }
        expect(load_ids).to include(posted_load.id)
      end
    end

    it 'includes pagination metadata' do
      create_list(:load, 15, status: 'posted')
      
      get '/api/v1/loads?per_page=10', as: :json, headers: auth_headers(carrier)

      expect(json_response['pagination']['current_page']).to eq(1)
      expect(json_response['pagination']['total_pages']).to eq(2)
    end
  end

  describe 'POST /api/v1/loads/:id/book' do
    let(:load) { create(:load, status: 'posted') }

    context 'as carrier' do
      before { authenticate_as(carrier) }

      it 'books the load successfully' do
        expect(LoadBookingService).to receive(:new).and_call_original
        
        post "/api/v1/loads/#{load.id}/book", as: :json

        expect(response).to have_http_status(:ok)
        expect(json_response['message']).to eq('Load booked successfully')
      end

      context 'when load is already booked' do
        before { create(:match, load: load, carrier: carrier.carrier_profile, status: 'accepted') }

        it 'returns error' do
          post "/api/v1/loads/#{load.id}/book", as: :json

          expect(response).to have_http_status(:unprocessable_entity)
        end
      end
    end

    context 'as shipper' do
      before { authenticate_as(shipper) }

      it 'returns forbidden' do
        post "/api/v1/loads/#{load.id}/book", as: :json

        expect(response).to have_http_status(:forbidden)
      end
    end
  end
end

# spec/requests/api/v1/auth_spec.rb
RSpec.describe 'Authentication API', type: :request do
  describe 'POST /api/v1/auth/login' do
    let(:user) { create(:user, email: 'test@example.com', password: 'SecurePassword123!') }

    context 'with valid credentials' do
      it 'returns authentication token' do
        post '/api/v1/auth/login', params: {
          email: user.email,
          password: 'SecurePassword123!'
        }, as: :json

        expect(response).to have_http_status(:ok)
        expect(json_response['token']).to be_present
        expect(json_response['user']['id']).to eq(user.id)
      end

      it 'creates audit log entry' do
        expect {
          post '/api/v1/auth/login', params: {
            email: user.email,
            password: 'SecurePassword123!'
          }, as: :json
        }.to change(AuditLog, :count).by(1)

        audit_log = AuditLog.last
        expect(audit_log.action).to eq('login_success')
      end
    end

    context 'with invalid credentials' do
      it 'returns error' do
        post '/api/v1/auth/login', params: {
          email: user.email,
          password: 'WrongPassword'
        }, as: :json

        expect(response).to have_http_status(:unauthorized)
        expect(json_response['error']).to eq('Invalid credentials')
      end

      it 'increments failed attempts' do
        expect {
          post '/api/v1/auth/login', params: {
            email: user.email,
            password: 'WrongPassword'
          }, as: :json
        }.to change { user.reload.failed_attempts }.by(1)
      end
    end

    context 'with locked account' do
      before { user.update!(failed_attempts: 5, locked_until: 1.hour.from_now) }

      it 'returns locked error' do
        post '/api/v1/auth/login', params: {
          email: user.email,
          password: 'SecurePassword123!'
        }, as: :json

        expect(response).to have_http_status(:unauthorized)
        expect(json_response['error']).to include('locked')
      end
    end

    context 'rate limiting' do
      it 'blocks excessive login attempts' do
        6.times do
          post '/api/v1/auth/login', params: {
            email: user.email,
            password: 'WrongPassword'
          }, as: :json
        end

        expect(response).to have_http_status(:too_many_requests)
      end
    end
  end
end
```

## 🎯 Frontend Testing with Jest & React Testing Library

### Component Testing
```typescript
// src/components/__tests__/LoadCard.test.tsx
import React from 'react';
import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { LoadCard } from '../LoadCard';
import { Load } from '../../types/Load';

const mockLoad: Load = {
  id: 1,
  pickupLocation: 'Atlanta, GA',
  deliveryLocation: 'Savannah, GA',
  pickupDatetime: '2025-08-01T10:00:00Z',
  deliveryDatetime: '2025-08-02T14:00:00Z',
  price: 2500,
  status: 'posted',
  distance: 248,
  weight: 15000,
  description: 'Electronics shipment'
};

describe('LoadCard', () => {
  const mockOnSelect = jest.fn();
  const mockOnBook = jest.fn();

  beforeEach(() => {
    jest.clearAllMocks();
  });

  it('renders load information correctly', () => {
    render(<LoadCard load={mockLoad} onSelect={mockOnSelect} onBook={mockOnBook} />);

    expect(screen.getByText('Atlanta, GA → Savannah, GA')).toBeInTheDocument();
    expect(screen.getByText('$2,500')).toBeInTheDocument();
    expect(screen.getByText('248 miles')).toBeInTheDocument();
    expect(screen.getByText('15,000 lbs')).toBeInTheDocument();
    expect(screen.getByText('Electronics shipment')).toBeInTheDocument();
  });

  it('displays correct status styling', () => {
    render(<LoadCard load={mockLoad} onSelect={mockOnSelect} onBook={mockOnBook} />);

    const statusElement = screen.getByText('POSTED');
    expect(statusElement).toHaveClass('status-posted');
  });

  it('calls onSelect when card is clicked', async () => {
    const user = userEvent.setup();
    render(<LoadCard load={mockLoad} onSelect={mockOnSelect} onBook={mockOnBook} />);

    await user.click(screen.getByRole('article'));

    expect(mockOnSelect).toHaveBeenCalledWith(mockLoad);
  });

  it('calls onBook when book button is clicked', async () => {
    const user = userEvent.setup();
    render(<LoadCard load={mockLoad} onSelect={mockOnSelect} onBook={mockOnBook} />);

    await user.click(screen.getByRole('button', { name: /book load/i }));

    expect(mockOnBook).toHaveBeenCalledWith(mockLoad);
  });

  it('shows urgent indicator for loads picking up soon', () => {
    const urgentLoad = {
      ...mockLoad,
      pickupDatetime: new Date(Date.now() + 12 * 60 * 60 * 1000).toISOString() // 12 hours from now
    };

    render(<LoadCard load={urgentLoad} onSelect={mockOnSelect} onBook={mockOnBook} />);

    expect(screen.getByText('URGENT')).toBeInTheDocument();
    expect(screen.getByText('URGENT')).toHaveClass('urgent-indicator');
  });

  it('displays price per mile calculation', () => {
    render(<LoadCard load={mockLoad} onSelect={mockOnSelect} onBook={mockOnBook} />);

    expect(screen.getByText('$10.08/mile')).toBeInTheDocument();
  });

  it('handles missing optional data gracefully', () => {
    const incompleteLoad = {
      ...mockLoad,
      weight: undefined,
      description: undefined
    };

    render(<LoadCard load={incompleteLoad} onSelect={mockOnSelect} onBook={mockOnBook} />);

    expect(screen.getByText('Atlanta, GA → Savannah, GA')).toBeInTheDocument();
    expect(screen.queryByText('lbs')).not.toBeInTheDocument();
  });

  it('shows loading state when booking', async () => {
    const user = userEvent.setup();
    mockOnBook.mockImplementation(() => new Promise(resolve => setTimeout(resolve, 1000)));

    render(<LoadCard load={mockLoad} onSelect={mockOnSelect} onBook={mockOnBook} />);

    await user.click(screen.getByRole('button', { name: /book load/i }));

    expect(screen.getByText('Booking...')).toBeInTheDocument();
    expect(screen.getByRole('button', { name: /booking/i })).toBeDisabled();
  });
});

// src/hooks/__tests__/useLoads.test.tsx
import { renderHook, waitFor } from '@testing-library/react';
import { rest } from 'msw';
import { setupServer } from 'msw/node';
import { useLoads } from '../useLoads';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import React from 'react';

const server = setupServer(
  rest.get('/api/v1/loads/search', (req, res, ctx) => {
    return res(ctx.json({
      data: [
        {
          id: 1,
          attributes: {
            pickup_location: 'Atlanta, GA',
            delivery_location: 'Savannah, GA',
            price: 2500,
            status: 'posted'
          }
        }
      ],
      pagination: {
        current_page: 1,
        total_pages: 1,
        total_count: 1
      }
    }));
  })
);

beforeAll(() => server.listen());
afterEach(() => server.resetHandlers());
afterAll(() => server.close());

const createWrapper = () => {
  const queryClient = new QueryClient({
    defaultOptions: {
      queries: {
        retry: false,
      },
    },
  });

  return ({ children }: { children: React.ReactNode }) => (
    <QueryClientProvider client={queryClient}>{children}</QueryClientProvider>
  );
};

describe('useLoads', () => {
  it('fetches loads successfully', async () => {
    const { result } = renderHook(
      () => useLoads({ origin: 'Atlanta, GA', radius: 50 }),
      { wrapper: createWrapper() }
    );

    expect(result.current.isLoading).toBe(true);

    await waitFor(() => {
      expect(result.current.isSuccess).toBe(true);
    });

    expect(result.current.data).toHaveLength(1);
    expect(result.current.data[0].pickupLocation).toBe('Atlanta, GA');
  });

  it('handles API errors', async () => {
    server.use(
      rest.get('/api/v1/loads/search', (req, res, ctx) => {
        return res(ctx.status(500), ctx.json({ error: 'Internal server error' }));
      })
    );

    const { result } = renderHook(
      () => useLoads({ origin: 'Atlanta, GA' }),
      { wrapper: createWrapper() }
    );

    await waitFor(() => {
      expect(result.current.isError).toBe(true);
    });

    expect(result.current.error).toBeDefined();
  });
});
```

### Integration Testing
```typescript
// src/pages/__tests__/LoadSearch.integration.test.tsx
import React from 'react';
import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { rest } from 'msw';
import { setupServer } from 'msw/node';
import { LoadSearchPage } from '../LoadSearchPage';
import { BrowserRouter } from 'react-router-dom';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';

const server = setupServer(
  rest.get('/api/v1/loads/search', (req, res, ctx) => {
    const url = req.url;
    const origin = url.searchParams.get('origin');
    
    if (origin === 'Atlanta') {
      return res(ctx.json({
        data: [
          {
            id: 1,
            attributes: {
              pickup_location: 'Atlanta, GA',
              delivery_location: 'Savannah, GA',
              price: 2500,
              status: 'posted'
            }
          }
        ]
      }));
    }
    
    return res(ctx.json({ data: [] }));
  }),

  rest.post('/api/v1/loads/:id/book', (req, res, ctx) => {
    return res(ctx.json({
      data: {
        id: 1,
        attributes: {
          status: 'accepted'
        }
      },
      message: 'Load booked successfully'
    }));
  })
);

beforeAll(() => server.listen());
afterEach(() => server.resetHandlers());
afterAll(() => server.close());

const TestWrapper = ({ children }: { children: React.ReactNode }) => {
  const queryClient = new QueryClient({
    defaultOptions: { queries: { retry: false } }
  });

  return (
    <BrowserRouter>
      <QueryClientProvider client={queryClient}>
        {children}
      </QueryClientProvider>
    </BrowserRouter>
  );
};

describe('LoadSearchPage Integration', () => {
  it('allows user to search and book loads', async () => {
    const user = userEvent.setup();
    
    render(<LoadSearchPage />, { wrapper: TestWrapper });

    // Search for loads
    const searchInput = screen.getByPlaceholderText('Enter pickup location');
    await user.type(searchInput, 'Atlanta');
    
    const searchButton = screen.getByRole('button', { name: /search/i });
    await user.click(searchButton);

    // Wait for results to load
    await waitFor(() => {
      expect(screen.getByText('Atlanta, GA → Savannah, GA')).toBeInTheDocument();
    });

    // Book a load
    const bookButton = screen.getByRole('button', { name: /book load/i });
    await user.click(bookButton);

    // Wait for success message
    await waitFor(() => {
      expect(screen.getByText('Load booked successfully')).toBeInTheDocument();
    });
  });

  it('handles no results gracefully', async () => {
    const user = userEvent.setup();
    
    render(<LoadSearchPage />, { wrapper: TestWrapper });

    const searchInput = screen.getByPlaceholderText('Enter pickup location');
    await user.type(searchInput, 'NonexistentCity');
    
    const searchButton = screen.getByRole('button', { name: /search/i });
    await user.click(searchButton);

    await waitFor(() => {
      expect(screen.getByText('No loads found matching your criteria')).toBeInTheDocument();
    });
  });
});
```

## 🔄 End-to-End Testing with Cypress

### Critical User Workflows
```typescript
// cypress/e2e/shipper-load-posting.cy.ts
describe('Shipper Load Posting Workflow', () => {
  beforeEach(() => {
    cy.login('shipper@example.com', 'SecurePassword123!');
  });

  it('allows shipper to post a new load', () => {
    cy.visit('/loads/new');

    // Fill out load form
    cy.get('[data-cy=pickup-location]').type('123 Main St, Atlanta, GA');
    cy.get('[data-cy=delivery-location]').type('456 Oak Ave, Savannah, GA');
    cy.get('[data-cy=pickup-date]').type('2025-08-01');
    cy.get('[data-cy=pickup-time]').type('10:00');
    cy.get('[data-cy=delivery-date]').type('2025-08-02');
    cy.get('[data-cy=delivery-time]').type('14:00');
    cy.get('[data-cy=weight]').type('15000');
    cy.get('[data-cy=price]').type('2500');
    cy.get('[data-cy=description]').type('Electronics shipment - fragile items');

    // Add equipment requirements
    cy.get('[data-cy=equipment-type]').select('dry_van');
    cy.get('[data-cy=temperature-controlled]').check();

    // Submit form
    cy.get('[data-cy=submit-load]').click();

    // Verify success
    cy.get('[data-cy=success-message]').should('contain', 'Load posted successfully');
    cy.url().should('include', '/loads');
    cy.get('[data-cy=load-card]').should('contain', 'Atlanta, GA → Savannah, GA');
  });

  it('validates required fields', () => {
    cy.visit('/loads/new');

    cy.get('[data-cy=submit-load]').click();

    cy.get('[data-cy=pickup-location-error]').should('contain', 'Pickup location is required');
    cy.get('[data-cy=delivery-location-error]').should('contain', 'Delivery location is required');
    cy.get('[data-cy=price-error]').should('contain', 'Price is required');
  });

  it('shows load matching in real-time', () => {
    cy.intercept('GET', '/api/v1/loads/*/matches', { fixture: 'load_matches.json' });

    cy.visit('/loads/new');
    cy.fillLoadForm();
    cy.get('[data-cy=submit-load]').click();

    // Navigate to load details
    cy.get('[data-cy=view-matches]').click();

    // Verify matches are displayed
    cy.get('[data-cy=match-card]').should('have.length.at.least', 1);
    cy.get('[data-cy=match-score]').should('be.visible');
    cy.get('[data-cy=carrier-rating]').should('be.visible');
  });
});

// cypress/e2e/carrier-load-booking.cy.ts
describe('Carrier Load Booking Workflow', () => {
  beforeEach(() => {
    cy.login('carrier@example.com', 'SecurePassword123!');
  });

  it('allows carrier to search and book loads', () => {
    cy.visit('/loads/search');

    // Search for loads
    cy.get('[data-cy=origin-input]').type('Atlanta, GA');
    cy.get('[data-cy=radius-slider]').invoke('val', 50).trigger('input');
    cy.get('[data-cy=search-button]').click();

    // Wait for results
    cy.get('[data-cy=load-results]').should('be.visible');
    cy.get('[data-cy=load-card]').should('have.length.at.least', 1);

    // Book a load
    cy.get('[data-cy=load-card]').first().within(() => {
      cy.get('[data-cy=book-button]').click();
    });

    // Confirm booking
    cy.get('[data-cy=confirm-booking]').click();

    // Verify success
    cy.get('[data-cy=booking-success]').should('contain', 'Load booked successfully');
    cy.url().should('include', '/bookings');
  });

  it('filters loads by equipment type', () => {
    cy.visit('/loads/search');

    cy.get('[data-cy=equipment-filter]').select('refrigerated');
    cy.get('[data-cy=search-button]').click();

    cy.get('[data-cy=load-card]').each(($card) => {
      cy.wrap($card).should('contain', 'Temperature Controlled');
    });
  });
});

// cypress/e2e/shipment-tracking.cy.ts
describe('Shipment Tracking Workflow', () => {
  it('tracks shipment in real-time', () => {
    cy.login('shipper@example.com', 'SecurePassword123!');
    cy.visit('/shipments/1');

    // Verify tracking information
    cy.get('[data-cy=shipment-status]').should('contain', 'In Transit');
    cy.get('[data-cy=progress-bar]').should('be.visible');
    cy.get('[data-cy=estimated-arrival]').should('be.visible');

    // Check map display
    cy.get('[data-cy=tracking-map]').should('be.visible');
    cy.get('[data-cy=current-location]').should('be.visible');

    // Verify tracking events
    cy.get('[data-cy=tracking-events]').within(() => {
      cy.get('[data-cy=tracking-event]').should('have.length.at.least', 2);
      cy.get('[data-cy=pickup-confirmed]').should('be.visible');
    });
  });

  it('updates tracking in real-time via WebSocket', () => {
    cy.login('carrier@example.com', 'SecurePassword123!');
    cy.visit('/shipments/1/update');

    // Simulate location update
    cy.get('[data-cy=current-lat]').type('33.7490');
    cy.get('[data-cy=current-lng]').type('-84.3880');
    cy.get('[data-cy=update-location]').click();

    // Verify WebSocket update (mock WebSocket in test)
    cy.get('[data-cy=location-updated]').should('contain', 'Location updated successfully');
  });
});
```

## 📊 Performance Testing

### Load Testing with Artillery
```yaml
# artillery-config.yml
config:
  target: 'http://localhost:3001'
  phases:
    - duration: 60
      arrivalRate: 10
      name: 'Warm up'
    - duration: 120
      arrivalRate: 50
      name: 'Sustained load'
    - duration: 60
      arrivalRate: 100
      name: 'Peak load'
  variables:
    shipper_token: '{{ $randomString() }}'
    carrier_token: '{{ $randomString() }}'

scenarios:
  - name: 'Load Search Performance'
    weight: 60
    flow:
      - get:
          url: '/api/v1/loads/search'
          headers:
            Authorization: 'Bearer {{ carrier_token }}'
          qs:
            origin: 'Atlanta, GA'
            radius: 50
          expect:
            - statusCode: 200
            - contentType: 'application/json'

  - name: 'Load Creation Performance'
    weight: 20
    flow:
      - post:
          url: '/api/v1/loads'
          headers:
            Authorization: 'Bearer {{ shipper_token }}'
            Content-Type: 'application/json'
          json:
            load:
              pickup_location: 'Atlanta, GA'
              delivery_location: 'Savannah, GA'
              price: 2500
          expect:
            - statusCode: 201

  - name: 'Matching Algorithm Performance'
    weight: 20
    flow:
      - post:
          url: '/api/v1/matching/find_carriers'
          headers:
            Authorization: 'Bearer {{ shipper_token }}'
          json:
            load_id: 1
            max_distance: 100
          expect:
            - statusCode: 200
            - hasProperty: 'carriers'
```

### Database Performance Testing
```ruby
# spec/performance/database_performance_spec.rb
RSpec.describe 'Database Performance', type: :performance do
  before(:all) do
    # Create test data
    create_list(:shipper_profile, 100)
    create_list(:carrier_profile, 500)
    create_list(:load, 10000, :posted)
    create_list(:match, 50000)
  end

  describe 'Load search queries' do
    it 'performs geographic search efficiently' do
      expect {
        Load.near_location(33.7490, -84.3880, 100).limit(50)
      }.to perform_under(100).ms
    end

    it 'handles full-text search efficiently' do
      expect {
        Load.where("search_vector @@ plainto_tsquery('electronics')")
            .limit(50)
      }.to perform_under(50).ms
    end

    it 'filters by multiple criteria efficiently' do
      expect {
        Load.joins(:load_requirements)
            .where(status: 'posted')
            .where('price BETWEEN ? AND ?', 1000, 5000)
            .where(load_requirements: { equipment_type: 'dry_van' })
            .limit(50)
      }.to perform_under(200).ms
    end
  end

  describe 'Matching algorithm queries' do
    it 'finds eligible carriers efficiently' do
      load = Load.first
      
      expect {
        CarrierProfile.joins(:vehicles)
                      .active
                      .near(load.pickup_location, 100)
                      .where(rating: 3.0..)
                      .limit(50)
      }.to perform_under(300).ms
    end
  end
end
```

*This comprehensive testing strategy ensures the freight matching platform maintains high quality, performance, and reliability throughout development and deployment.*
