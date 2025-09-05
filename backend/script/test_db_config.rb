#!/usr/bin/env ruby
# Test script to verify database configuration and routing setup

require 'yaml'
require 'erb'

def test_database_config
  puts "🔍 Testing Database Configuration..."
  
  config_file = File.join(__dir__, '..', 'config', 'database.yml')
  
  unless File.exist?(config_file)
    puts "❌ database.yml not found"
    return false
  end
  
  begin
    # Parse database.yml like Rails does
    raw_config = File.read(config_file)
    erb_config = ERB.new(raw_config).result
    config = YAML.load(erb_config, aliases: true)
    
    puts "✅ database.yml parsed successfully"
    
    # Test development configuration
    dev_config = config['development']
    if dev_config.is_a?(Hash) && dev_config.key?('primary') && dev_config.key?('replica')
      puts "✅ Development: Multiple database configuration found"
      puts "   Primary: #{dev_config['primary']['host']}:#{dev_config['primary']['port']}"
      puts "   Replica: #{dev_config['replica']['host']}:#{dev_config['replica']['port']}"
    else
      puts "❌ Development: Multiple database configuration missing"
      return false
    end
    
    # Test production configuration  
    prod_config = config['production']
    if prod_config.is_a?(Hash) && prod_config.key?('primary') && prod_config.key?('replica')
      puts "✅ Production: Multiple database configuration found"
    else
      puts "❌ Production: Multiple database configuration missing"
      return false
    end
    
    # Check connection pool settings
    if dev_config['primary']['pool'] && dev_config['primary']['pool'] > 5
      puts "✅ Connection pool optimized (size: #{dev_config['primary']['pool']})"
    else
      puts "⚠️  Connection pool not optimized"
    end
    
    return true
    
  rescue => e
    puts "❌ Error parsing database.yml: #{e.message}"
    return false
  end
end

def test_application_record
  puts "\n🔍 Testing ApplicationRecord Configuration..."
  
  app_record_file = File.join(__dir__, '..', 'app', 'models', 'application_record.rb')
  
  unless File.exist?(app_record_file)
    puts "❌ ApplicationRecord not found"
    return false
  end
  
  content = File.read(app_record_file)
  
  if content.include?('connects_to database:')
    puts "✅ Multiple database configuration found in ApplicationRecord"
  else
    puts "❌ Multiple database configuration missing in ApplicationRecord"
    return false
  end
  
  if content.include?('writing: :primary') && content.include?('reading: :replica')
    puts "✅ Read/write routing configuration found"
  else
    puts "❌ Read/write routing configuration missing"
    return false
  end
  
  if content.include?('with_primary_db') && content.include?('with_replica_db')
    puts "✅ Database routing helper methods found"
  else
    puts "❌ Database routing helper methods missing"
    return false
  end
  
  return true
end

def test_database_router
  puts "\n🔍 Testing DatabaseRouter..."
  
  router_file = File.join(__dir__, '..', 'lib', 'database_router.rb')
  
  unless File.exist?(router_file)
    puts "❌ DatabaseRouter not found"
    return false
  end
  
  content = File.read(router_file)
  
  if content.include?('with_read_routing') && content.include?('with_write_routing')
    puts "✅ Read/write routing methods found"
  else
    puts "❌ Read/write routing methods missing"
    return false
  end
  
  if content.include?('replica_healthy?') && content.include?('check_replica_health')
    puts "✅ Health check methods found"
  else
    puts "❌ Health check methods missing"
    return false
  end
  
  if content.include?('enable_primary_only_mode!') && content.include?('disable_primary_only_mode!')
    puts "✅ Failover methods found"
  else
    puts "❌ Failover methods missing"
    return false
  end
  
  if content.include?('with_load_balanced_read')
    puts "✅ Load balancing support found"
  else
    puts "❌ Load balancing support missing"
    return false
  end
  
  return true
end

def test_database_initializer
  puts "\n🔍 Testing Database Initializer..."
  
  init_file = File.join(__dir__, '..', 'config', 'initializers', 'database.rb')
  
  unless File.exist?(init_file)
    puts "❌ Database initializer not found"
    return false
  end
  
  content = File.read(init_file)
  
  if content.include?('DatabasePoolMonitor')
    puts "✅ Connection pool monitoring found"
  else
    puts "❌ Connection pool monitoring missing"
    return false
  end
  
  if content.include?('monitor_pools') && content.include?('monitor_pool')
    puts "✅ Pool monitoring methods found"
  else
    puts "❌ Pool monitoring methods missing"
    return false
  end
  
  if content.include?('SLOW QUERY') || content.include?('sql.active_record')
    puts "✅ Query performance monitoring found"
  else
    puts "❌ Query performance monitoring missing"
    return false
  end
  
  return true
end

def test_docker_configuration
  puts "\n🔍 Testing Docker Configuration..."
  
  docker_file = File.join(__dir__, '..', '..', 'docker-compose.yml')
  
  unless File.exist?(docker_file)
    puts "❌ docker-compose.yml not found"
    return false
  end
  
  content = File.read(docker_file)
  
  if content.include?('postgres_replica1') && content.include?('postgres_replica2')
    puts "✅ Read replica services found in docker-compose.yml"
  else
    puts "❌ Read replica services missing in docker-compose.yml"
    return false
  end
  
  if content.include?('postgres_replica1_data') && content.include?('postgres_replica2_data')
    puts "✅ Replica data volumes found"
  else
    puts "❌ Replica data volumes missing"
    return false
  end
  
  if content.include?('5433:5432') && content.include?('5434:5432')
    puts "✅ Replica port mappings found"
  else
    puts "❌ Replica port mappings missing"
    return false
  end
  
  return true
end

def test_postgresql_configs
  puts "\n🔍 Testing PostgreSQL Configuration Files..."
  
  primary_conf = File.join(__dir__, '..', '..', 'scripts', 'postgres-primary.conf')
  replica_conf = File.join(__dir__, '..', '..', 'scripts', 'postgres-replica.conf')
  setup_script = File.join(__dir__, '..', '..', 'scripts', 'setup-replica.sh')
  
  files_ok = true
  
  if File.exist?(primary_conf)
    content = File.read(primary_conf)
    if content.include?('wal_level = replica') && content.include?('max_wal_senders')
      puts "✅ Primary PostgreSQL configuration found with replication settings"
    else
      puts "❌ Primary PostgreSQL configuration missing replication settings"
      files_ok = false
    end
  else
    puts "❌ Primary PostgreSQL configuration not found"
    files_ok = false
  end
  
  if File.exist?(replica_conf)
    content = File.read(replica_conf)
    if content.include?('hot_standby = on') && content.include?('standby_mode')
      puts "✅ Replica PostgreSQL configuration found with standby settings"
    else
      puts "❌ Replica PostgreSQL configuration missing standby settings"
      files_ok = false
    end
  else
    puts "❌ Replica PostgreSQL configuration not found"
    files_ok = false
  end
  
  if File.exist?(setup_script) && File.executable?(setup_script)
    content = File.read(setup_script)
    if content.include?('pg_basebackup') && content.include?('recovery.conf')
      puts "✅ Replica setup script found with base backup logic"
    else
      puts "❌ Replica setup script missing base backup logic"
      files_ok = false
    end
  else
    puts "❌ Replica setup script not found or not executable"
    files_ok = false
  end
  
  return files_ok
end

# Run all tests
puts "🚀 Database Connection Pooling and Read Replicas Configuration Test"
puts "=" * 70

all_passed = true
all_passed &= test_database_config
all_passed &= test_application_record
all_passed &= test_database_router
all_passed &= test_database_initializer
all_passed &= test_docker_configuration
all_passed &= test_postgresql_configs

puts "\n" + "=" * 70
if all_passed
  puts "✅ ALL TESTS PASSED - Configuration is ready for database scaling!"
  puts "\nNext steps:"
  puts "1. Start the services: docker compose up -d postgres postgres_replica1 postgres_replica2"
  puts "2. Run database migrations: bundle exec rails db:migrate"
  puts "3. Test read/write routing with your application"
  puts "4. Monitor connection pool utilization in logs"
  exit 0
else
  puts "❌ SOME TESTS FAILED - Please review the configuration"
  exit 1
end