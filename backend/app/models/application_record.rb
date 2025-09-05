class ApplicationRecord < ActiveRecord::Base
  primary_abstract_class
  
  # Configure multiple databases for read/write splitting
  # This enables automatic routing of read queries to replicas
  connects_to database: {
    writing: :primary,
    reading: :replica
  }
  
  # Class method to force writing database for specific operations
  def self.with_primary_db(&block)
    connected_to(role: :writing, &block)
  end
  
  # Class method to force reading database for specific operations  
  def self.with_replica_db(&block)
    connected_to(role: :reading, &block)
  end
  
  # Instance method to ensure writes go to primary
  def with_primary_db(&block)
    self.class.with_primary_db(&block)
  end
end
