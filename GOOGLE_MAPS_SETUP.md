# Google Maps API Integration Setup

## API Key Configuration

To enable full Google Maps integration for route calculation, add your API key to the Rails application:

### Option 1: Rails Credentials (Recommended)
```bash
# Edit encrypted credentials
rails credentials:edit

# Add this to the credentials file:
google_maps_api_key: your_actual_api_key_here
```

### Option 2: Environment Variable
```bash
# Set environment variable
export GOOGLE_MAPS_API_KEY=your_actual_api_key_here

# Or add to .env file (if using dotenv gem)
GOOGLE_MAPS_API_KEY=your_actual_api_key_here
```

## Required Google Maps APIs

Enable these APIs in your Google Cloud Console:

1. **Directions API** - For route calculation
2. **Distance Matrix API** - For distance calculations
3. **Geocoding API** - For address to coordinates conversion
4. **Roads API** (Optional) - For enhanced route optimization

## API Usage in RouteCalculationService

The service automatically detects API availability and falls back to basic calculations if no API key is configured:

```ruby
def google_maps_available?
  google_maps_api_key.present?
end

def google_maps_api_key
  Rails.application.credentials.google_maps_api_key || ENV['GOOGLE_MAPS_API_KEY']
end
```

## Cost Optimization

- API calls are cached for 2 hours per route
- Fallback calculations reduce API dependency
- Batch requests minimize API costs

## Testing Without API Key

The application works fully without Google Maps API - it uses:
- Geocoder gem for basic distance calculations
- Mathematical estimations for route optimization
- Realistic cost calculations based on industry standards

## Production Setup

1. Get Google Maps API key from Google Cloud Console
2. Set appropriate quotas and billing limits
3. Configure API key in production credentials
4. Monitor API usage in Google Cloud Console