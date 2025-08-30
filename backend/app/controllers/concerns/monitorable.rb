# app/controllers/concerns/monitorable.rb
module Monitorable
  extend ActiveSupport::Concern

  included do
    around_action :track_request_metrics
    rescue_from StandardError, with: :track_error
  end

  private

  def track_request_metrics
    start = Time.now
    yield
    duration = Time.now - start
    RESPONSE_TIME.observe({}, duration)
    REQUEST_COUNTER.increment
  end

  def track_error(exception)
    ERROR_COUNTER.increment
    Rails.logger.error("Error tracked: #{exception.message}")
    raise exception
  end
end
