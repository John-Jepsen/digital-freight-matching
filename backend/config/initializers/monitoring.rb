# config/initializers/monitoring.rb
require 'prometheus/client'

PROMETHEUS = Prometheus::Client.registry

# Example metrics
REQUEST_COUNTER = PROMETHEUS.counter(:http_requests_total, 'A counter of all HTTP requests')
ERROR_COUNTER   = PROMETHEUS.counter(:http_errors_total, 'A counter of failed requests')
RESPONSE_TIME   = PROMETHEUS.histogram(:http_response_time, 'Response time in seconds')

Rails.logger.info("Monitoring initialized with Prometheus")
