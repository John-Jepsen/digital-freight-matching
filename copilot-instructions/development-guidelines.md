# Development Guidelines & Standards

## Technology Stack

### Backend (Ruby on Rails 8.0.2)
- **Framework**: Rails API-only mode with Ruby 3.2+
- **Database**: PostgreSQL 16 with ActiveRecord ORM
- **Authentication**: JWT tokens with Devise
- **Authorization**: Pundit for role-based access control
- **Background Jobs**: Sidekiq with sidekiq-cron
- **State Management**: AASM for state machines
- **Geocoding**: Geocoder gem with Google Maps API
- **Caching**: Redis for sessions and performance

### Frontend (React 18 + TypeScript)
- **Framework**: React 18 with TypeScript for type safety
- **Build Tool**: Vite for fast development and builds
- **Testing**: Jest + React Testing Library
- **Package Manager**: npm

### Infrastructure
- **Containerization**: Docker & Docker Compose
- **Development**: Hot reload for both Rails and React
- **Database**: PostgreSQL with Row-Level Security (RLS)

## Project Structure

```
backend/
├── app/
│   ├── controllers/api/v1/    # RESTful API endpoints
│   ├── models/                # ActiveRecord models with validations
│   ├── services/              # Business logic services
│   ├── jobs/                  # Background processing jobs
│   └── channels/              # ActionCable for real-time features
├── config/                    # Application configuration
├── db/                        # Database migrations and seeds
└── lib/                       # Custom libraries and tasks

frontend/
├── web-app/                   # Main user interface (port 3000)
│   └── src/
└── admin-dashboard/           # Admin interface (port 3002)
    └── src/
```

## Coding Standards

### Rails API Development

#### Model Conventions
```ruby
# Use AASM for state machines
class Load < ApplicationRecord
  include AASM
  
  aasm column: :status do
    state :posted, initial: true
    state :matched, :in_transit, :delivered, :cancelled
    
    event :match_carrier do
      transitions from: :posted, to: :matched
    end
  end
  
  # Comprehensive validations
  validates :pickup_location, :delivery_location, presence: true
  validates :price, presence: true, numericality: { greater_than: 0 }
  validates :pickup_datetime, presence: true
  validate :pickup_before_delivery
  
  # Use scopes for common queries
  scope :available, -> { where(status: 'posted') }
  scope :near_location, ->(lat, lng, radius) { /* geographic query */ }
  
  # Geocoding for addresses
  geocoded_by :pickup_location, latitude: :pickup_lat, longitude: :pickup_lng
  after_validation :geocode
end
```

#### Service Objects Pattern
```ruby
# Business logic in service classes
class MatchingAlgorithmService
  def initialize(load, options = {})
    @load = load
    @max_distance = options[:max_distance] || 100
    @min_rating = options[:min_rating] || 0
  end
  
  def call
    carriers = find_eligible_carriers
    matches = calculate_match_scores(carriers)
    
    ServiceResult.new(
      success: true,
      data: matches.limit(10)
    )
  rescue => e
    ServiceResult.new(
      success: false,
      error: e.message
    )
  end
  
  private
  
  def find_eligible_carriers
    CarrierProfile.joins(:vehicles)
                  .near(@load.pickup_location, @max_distance)
                  .where(rating: @min_rating..)
                  .active
  end
end
```

#### Controller Best Practices
```ruby
class Api::V1::LoadsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_load, only: [:show, :update, :destroy]
  
  def create
    authorize Load
    
    @load = current_user.shipper_profile.loads.build(load_params)
    
    if @load.save
      render json: LoadSerializer.new(@load), status: :created
    else
      render json: { errors: @load.errors }, status: :unprocessable_entity
    end
  end
  
  def search
    service = LoadSearchService.new(search_params)
    result = service.call
    
    if result.success?
      render json: {
        loads: LoadSerializer.new(result.data),
        pagination: pagination_data(result.data)
      }
    else
      render json: { error: result.error }, status: :bad_request
    end
  end
  
  private
  
  def load_params
    params.require(:load).permit(:pickup_location, :delivery_location, 
                                 :pickup_datetime, :delivery_datetime,
                                 :weight, :price, :description)
  end
  
  def authorize_load_access
    authorize @load
  end
end
```

### React Frontend Development

#### Component Structure
```typescript
// TypeScript interfaces for type safety
interface Load {
  id: number;
  pickupLocation: string;
  deliveryLocation: string;
  price: number;
  status: LoadStatus;
  pickupDatetime: string;
  deliveryDatetime: string;
}

// Functional components with hooks
const LoadCard: React.FC<{ load: Load; onSelect: (load: Load) => void }> = ({ 
  load, 
  onSelect 
}) => {
  const handleClick = useCallback(() => {
    onSelect(load);
  }, [load, onSelect]);

  return (
    <div className="load-card" onClick={handleClick}>
      <h3>{load.pickupLocation} → {load.deliveryLocation}</h3>
      <p>Price: ${load.price.toLocaleString()}</p>
      <span className={`status status-${load.status}`}>
        {load.status.replace('_', ' ').toUpperCase()}
      </span>
    </div>
  );
};
```

#### State Management
```typescript
// Custom hooks for API calls
const useLoads = (filters: LoadFilters) => {
  const [loads, setLoads] = useState<Load[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const fetchLoads = useCallback(async () => {
    setLoading(true);
    setError(null);
    
    try {
      const response = await api.get('/loads/search', { params: filters });
      setLoads(response.data.loads);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to fetch loads');
    } finally {
      setLoading(false);
    }
  }, [filters]);

  useEffect(() => {
    fetchLoads();
  }, [fetchLoads]);

  return { loads, loading, error, refetch: fetchLoads };
};
```

## Database Design Principles

### Model Relationships
```ruby
# Core entity relationships
class User < ApplicationRecord
  has_one :shipper_profile, dependent: :destroy
  has_one :carrier_profile, dependent: :destroy
  
  enum user_type: { shipper: 'shipper', carrier: 'carrier', admin: 'admin' }
end

class Load < ApplicationRecord
  belongs_to :shipper, class_name: 'ShipperProfile'
  has_many :matches, dependent: :destroy
  has_many :carriers, through: :matches
  has_one :shipment, dependent: :destroy
  has_many :load_requirements, dependent: :destroy
  has_many :cargo_details, dependent: :destroy
end

class Match < ApplicationRecord
  belongs_to :load
  belongs_to :carrier, class_name: 'CarrierProfile'
  has_one :route, dependent: :destroy
  has_one :shipment, dependent: :destroy
  
  validates :load_id, uniqueness: { scope: :carrier_id }
end
```

### Database Indexing Strategy
```sql
-- Performance-critical indexes
CREATE INDEX idx_loads_status_pickup_date ON loads(status, pickup_datetime);
CREATE INDEX idx_loads_location_search ON loads(pickup_lat, pickup_lng);
CREATE INDEX idx_matches_load_carrier ON matches(load_id, carrier_id);
CREATE INDEX idx_tracking_events_shipment ON tracking_events(shipment_id, occurred_at DESC);
```

## Security Guidelines

### Authentication & Authorization
```ruby
# JWT token authentication
class ApplicationController < ActionController::API
  before_action :authenticate_user!
  
  private
  
  def authenticate_user!
    token = request.headers['Authorization']&.split(' ')&.last
    
    if token.present?
      begin
        @current_user = User.find(JWT.decode(token, Rails.application.secret_key_base)[0]['user_id'])
      rescue JWT::DecodeError
        render json: { error: 'Invalid token' }, status: :unauthorized
      end
    else
      render json: { error: 'Token missing' }, status: :unauthorized
    end
  end
  
  def current_user
    @current_user
  end
end

# Pundit authorization policies
class LoadPolicy < ApplicationPolicy
  def create?
    user.shipper?
  end
  
  def show?
    record.shipper.user == user || user.admin?
  end
  
  def update?
    record.shipper.user == user
  end
end
```

### Data Validation & Sanitization
```ruby
class Load < ApplicationRecord
  validates :pickup_location, presence: true, length: { maximum: 500 }
  validates :delivery_location, presence: true, length: { maximum: 500 }
  validates :price, presence: true, numericality: { greater_than: 0, less_than: 1_000_000 }
  validates :weight, numericality: { greater_than: 0, less_than: 80_000 }, allow_nil: true
  validate :pickup_datetime_in_future
  validate :delivery_after_pickup
  
  before_save :sanitize_text_fields
  
  private
  
  def sanitize_text_fields
    self.description = ActionController::Base.helpers.strip_tags(description) if description.present?
  end
end
```

## Testing Standards

### RSpec for Backend
```ruby
# Model specs
RSpec.describe Load, type: :model do
  describe 'validations' do
    it { should validate_presence_of(:pickup_location) }
    it { should validate_presence_of(:delivery_location) }
    it { should validate_numericality_of(:price).is_greater_than(0) }
  end
  
  describe 'state machine' do
    let(:load) { create(:load) }
    
    it 'starts in posted state' do
      expect(load).to be_posted
    end
    
    it 'can transition to matched' do
      expect { load.match_carrier! }.to change(load, :status).to('matched')
    end
  end
end

# Service specs
RSpec.describe MatchingAlgorithmService do
  describe '#call' do
    let(:load) { create(:load) }
    let(:service) { described_class.new(load) }
    
    context 'with available carriers' do
      before { create_list(:carrier_profile, 3, :active) }
      
      it 'returns successful result' do
        result = service.call
        expect(result).to be_success
        expect(result.data).to be_present
      end
    end
  end
end
```

### Jest for Frontend
```typescript
// Component testing
import { render, screen, fireEvent } from '@testing-library/react';
import LoadCard from './LoadCard';

describe('LoadCard', () => {
  const mockLoad: Load = {
    id: 1,
    pickupLocation: 'Atlanta, GA',
    deliveryLocation: 'Savannah, GA',
    price: 2500,
    status: 'posted',
    pickupDatetime: '2025-08-01T10:00:00Z',
    deliveryDatetime: '2025-08-02T14:00:00Z'
  };

  it('renders load information correctly', () => {
    render(<LoadCard load={mockLoad} onSelect={() => {}} />);
    
    expect(screen.getByText('Atlanta, GA → Savannah, GA')).toBeInTheDocument();
    expect(screen.getByText('Price: $2,500')).toBeInTheDocument();
    expect(screen.getByText('POSTED')).toBeInTheDocument();
  });

  it('calls onSelect when clicked', () => {
    const mockOnSelect = jest.fn();
    render(<LoadCard load={mockLoad} onSelect={mockOnSelect} />);
    
    fireEvent.click(screen.getByText('Atlanta, GA → Savannah, GA'));
    expect(mockOnSelect).toHaveBeenCalledWith(mockLoad);
  });
});
```

## Performance Guidelines

### Database Optimization
- Use database indexes on frequently queried columns
- Implement pagination for large result sets
- Use `includes` to prevent N+1 queries
- Cache expensive calculations in Redis
- Use database views for complex analytical queries

### Frontend Performance
- Implement lazy loading for routes and components
- Use React.memo for expensive components
- Debounce search inputs
- Implement virtual scrolling for large lists
- Optimize bundle size with code splitting

## Development Commands Reference

### Backend Development
```bash
# Setup and database
bundle install
rails db:create db:migrate db:seed

# Development server with hot reload
rails server -p 3001

# Background jobs
bundle exec sidekiq -C config/sidekiq.yml

# Testing
bundle exec rspec
COVERAGE=true bundle exec rspec

# Code quality
bundle exec rubocop
bundle exec brakeman
```

### Frontend Development
```bash
# Setup
npm install

# Development servers
npm run dev          # Web app (port 3000)
npm start           # Admin dashboard (port 3002)

# Testing and build
npm test
npm run build
npm run preview
```

### Docker Development
```bash
# Start infrastructure services
docker compose up -d postgres redis

# Full stack development
docker compose up

# View service logs
docker compose logs -f backend
```

## Code Review Checklist

### Backend PR Review
- [ ] Models have proper validations and associations
- [ ] Services follow single responsibility principle
- [ ] Controllers are thin with proper error handling
- [ ] Database migrations are reversible
- [ ] Tests cover happy path and edge cases
- [ ] Security policies implemented with Pundit
- [ ] Performance considerations (indexes, N+1 queries)

### Frontend PR Review
- [ ] Components follow TypeScript best practices
- [ ] Proper error handling and loading states
- [ ] Accessibility considerations (ARIA labels, keyboard navigation)
- [ ] Responsive design implementation
- [ ] Performance optimizations (memo, callbacks)
- [ ] Tests cover user interactions
- [ ] Consistent styling and UX patterns

*These guidelines ensure code quality, maintainability, and scalability as the platform grows.*
