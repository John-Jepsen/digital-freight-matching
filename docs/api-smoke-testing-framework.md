# API Stub Smoke-Testing Framework

A comprehensive framework for testing API endpoints to ensure they are responding correctly and meeting performance expectations. This framework automatically discovers all API endpoints and runs categorized smoke tests with detailed reporting.

## Features

- **Automatic Endpoint Discovery**: Discovers all API routes from Rails routing table
- **Categorized Testing**: Different test strategies for different endpoint types
- **Authentication Handling**: Automatic token generation and management for protected endpoints
- **Response Validation**: Validates status codes, content types, and basic response structure
- **Performance Metrics**: Tracks response times and identifies slow endpoints
- **Multiple Report Formats**: Text, JSON, and HTML reporting
- **CLI Interface**: Command-line tool for easy integration with CI/CD
- **RSpec Integration**: Full integration with existing test suite
- **Rake Tasks**: Convenient rake tasks for common operations

## Installation

The framework is already included in the project. No additional installation required.

## Quick Start

### Using Rake Tasks

```bash
# Run all smoke tests
rake smoke_test:all

# Run specific category tests
rake smoke_test:category[health_check]
rake smoke_test:category[authentication]

# Discover all endpoints
rake smoke_test:discover

# Run health checks only
rake smoke_test:health

# Generate HTML report
rake smoke_test:report[html]
```

### Using CLI

```bash
# Run all tests
./bin/smoke_test all

# Run category tests
./bin/smoke_test category health_check

# Discover endpoints
./bin/smoke_test discover

# Show help
./bin/smoke_test help
```

### Using RSpec

```bash
# Run the smoke test suite
bundle exec rspec spec/smoke_test_spec.rb

# Run with verbose output
bundle exec rspec spec/smoke_test_spec.rb -v
```

## Configuration

### Environment Variables

- `SMOKE_TEST_BASE_URL`: Base URL for API testing (default: `http://localhost:3001`)
- `SMOKE_TEST_TIMEOUT`: Request timeout in seconds (default: `30`)
- `RAILS_ENV`: Environment setting (default: `test`)

### Configuration File

Copy `config/smoke_test.yml.example` to `config/smoke_test.yml` and customize:

```yaml
development:
  base_url: http://localhost:3001
  timeout: 30
  categories:
    - health_check
    - authentication
  performance:
    max_response_time: 5000
```

## Endpoint Categories

The framework automatically categorizes endpoints:

- **health_check**: Health and status endpoints
- **authentication**: Login, register, logout, profile endpoints
- **list_resource**: GET /resource (index actions)
- **get_resource**: GET /resource/:id (show actions)
- **create_resource**: POST /resource (create actions)
- **update_resource**: PUT/PATCH /resource/:id (update actions)
- **delete_resource**: DELETE /resource/:id (destroy actions)
- **custom_action**: Custom endpoint actions

## Test Strategies

### Health Check Tests
- Validates 200 status code
- Checks for JSON response with status field
- Verifies response time under threshold

### Authentication Tests
- Tests login with invalid credentials (expects 401)
- Tests login with valid credentials (expects token)
- Tests protected endpoints without token (expects 401)
- Tests protected endpoints with valid token

### Resource Tests
- **List endpoints**: Tests GET /resource with authentication
- **Show endpoints**: Tests GET /resource/1 (accepts 200 or 404)
- **Create endpoints**: Tests POST with sample data
- **Update endpoints**: Tests PUT/PATCH with sample data
- **Delete endpoints**: Tests DELETE (accepts 200, 204, or 404)

## Response Validation

Each test validates:
- HTTP status codes are appropriate for the endpoint type
- Response times are within acceptable limits
- Content-Type headers are correct
- Basic response structure (JSON format for API endpoints)
- Authentication token presence for protected endpoints

## Sample Test Data

The framework includes built-in test data generators for common resources:

```ruby
# Load test data
{
  load: {
    pickup_location: "Dallas, TX",
    delivery_location: "Austin, TX",
    pickup_datetime: 2.days.from_now.iso8601,
    delivery_datetime: 5.days.from_now.iso8601,
    weight: 1000,
    price: 500,
    description: "Test load for smoke testing",
    equipment_type: "dry_van"
  }
}

# Carrier test data
{
  carrier: {
    company_name: "Test Carrier #{Time.current.to_i}",
    phone: "555-0123",
    equipment_types: ["dry_van"],
    service_areas: ["TX", "OK"]
  }
}
```

## Reporting

### Text Report
```
API SMOKE TEST RESULTS
======================

Test Summary:
  Total Tests: 25
  Passed: 23
  Failed: 2
  Success Rate: 92.0%
  Total Duration: 1250ms
  Average Response Time: 50ms

Results by Category:
  Health Check: Total: 3, Passed: 3, Failed: 0 (100.0%)
  Authentication: Total: 7, Passed: 6, Failed: 1 (85.7%)
  ...
```

### JSON Report
```json
{
  "summary": {
    "total_tests": 25,
    "passed_count": 23,
    "failed_count": 2,
    "success_rate": 92.0,
    "total_duration_ms": 1250
  },
  "results": [
    {
      "endpoint": {
        "path": "/api/v1/health",
        "method": "get",
        "category": "health_check"
      },
      "passed": true,
      "status": 200,
      "response_time_ms": 45
    }
  ]
}
```

### HTML Report
Generated HTML report with styling and interactive elements for easy viewing in browsers.

## Integration with CI/CD

### GitHub Actions Example

```yaml
name: API Smoke Tests
on: [push, pull_request]

jobs:
  smoke-tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Setup Ruby
        uses: ruby/setup-ruby@v1
        with:
          ruby-version: 3.2
      - name: Install dependencies
        run: bundle install
      - name: Start test server
        run: |
          bundle exec rails server -p 3001 -e test &
          sleep 10
      - name: Run smoke tests
        run: rake smoke_test:all
```

### Jenkins Pipeline Example

```groovy
pipeline {
    agent any
    stages {
        stage('Smoke Tests') {
            steps {
                script {
                    sh 'bundle install'
                    sh 'bundle exec rails server -p 3001 -e test &'
                    sleep(10)
                    sh 'rake smoke_test:all'
                }
            }
            post {
                always {
                    publishHTML([
                        allowMissing: false,
                        alwaysLinkToLastBuild: true,
                        keepAll: true,
                        reportDir: 'tmp/smoke_test_reports',
                        reportFiles: '*.html',
                        reportName: 'Smoke Test Report'
                    ])
                }
            }
        }
    }
}
```

## Performance Monitoring

The framework tracks performance metrics:

- **Response Times**: Individual endpoint response times
- **Average Response Time**: Overall average across all tests
- **Slowest Endpoint**: Identifies the slowest responding endpoint
- **Fastest Endpoint**: Identifies the fastest responding endpoint
- **Category Performance**: Performance breakdown by endpoint category

### Performance Thresholds

Default thresholds (configurable):
- Health checks: < 1000ms
- Authentication: < 2000ms
- General endpoints: < 5000ms

## Error Handling

The framework gracefully handles:
- Network timeouts and connection errors
- Invalid authentication tokens
- Missing or malformed endpoints
- Server errors (5xx responses)
- Rate limiting responses

## Advanced Usage

### Programmatic Usage

```ruby
# Configure the framework
ApiSmokeTestFramework.configure do |config|
  config.base_url = 'https://api.example.com'
  config.timeout = 60
end

# Create orchestrator
orchestrator = ApiSmokeTestFramework::SmokeTestOrchestrator.new

# Discover endpoints
endpoints = orchestrator.discover_endpoints

# Run tests
results = orchestrator.run_all_tests

# Generate report
report = orchestrator.generate_report(format: :json)
```

### Custom Test Runners

You can extend the framework with custom test runners:

```ruby
class CustomTestRunner < ApiSmokeTestFramework::BaseTestRunner
  def execute_test(endpoint, options)
    # Custom test logic
  end

  def evaluate_response(response, endpoint)
    # Custom response validation
  end
end
```

## Troubleshooting

### Common Issues

1. **Connection Refused**: Ensure the API server is running on the configured URL
2. **Authentication Failures**: Check test credentials in configuration
3. **Timeout Errors**: Increase timeout setting for slow environments
4. **Permission Errors**: Ensure test user has appropriate permissions

### Debug Mode

Enable debug logging:

```bash
# Set log level
RAILS_ENV=development rake smoke_test:all

# Or configure in code
ApiSmokeTestFramework.configure do |config|
  config.logger.level = Logger::DEBUG
end
```

## Best Practices

1. **Run Health Checks First**: Always verify basic connectivity before comprehensive testing
2. **Use Appropriate Test Data**: Ensure test data matches expected schemas
3. **Monitor Performance**: Set appropriate thresholds for your environment
4. **Regular Execution**: Run smoke tests regularly as part of your deployment pipeline
5. **Review Failed Tests**: Investigate and fix failing tests promptly

## Contributing

1. Fork the repository
2. Create a feature branch
3. Add tests for new functionality
4. Ensure all tests pass
5. Submit a pull request

## License

This framework is part of the Digital Freight Matching Platform and follows the same license terms.