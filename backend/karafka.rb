# Karafka configuration for Digital Freight Matching Platform
# This file configures Kafka integration for event-driven architecture

class KarafkaApp < Karafka::App
  setup do |config|
    config.kafka = {
      'bootstrap.servers': ENV.fetch('KAFKA_URL', 'localhost:9092')
    }
    config.app_id = 'freight_matching_api'
    config.logger = Rails.logger
    config.monitor = Karafka::Instrumentation::Monitor.new
  end

  # Define consumer routes here
  routes.draw do
    # Example: Load matching events
    # topic :load_created do
    #   consumer LoadCreatedConsumer
    # end
    
    # Example: Carrier location updates
    # topic :carrier_location_updated do
    #   consumer CarrierLocationConsumer
    # end
  end
end

Karafka.monitor.subscribe(Karafka::Instrumentation::LoggerListener.new)