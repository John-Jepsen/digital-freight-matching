# config/initializers/monitoring.rb
require 'prometheus/client'

PROMETHEUS = Prometheus::Client.registry

# Example metrics (new API requires `docstring:`)
REQUEST_COUNTER = PROMETHEUS.counter(:http_requests_total, docstring: 'A counter of all HTTP requests')
ERROR_COUNTER   = PROMETHEUS.counter(:http_errors_total, docstring: 'A counter of failed requests')
RESPONSE_TIME   = PROMETHEUS.histogram(:http_response_time, docstring: 'Response time in seconds', labels: [:method, :path])
