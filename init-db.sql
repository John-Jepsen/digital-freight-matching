-- Digital Freight Matching Platform Database Initialization
-- This script initializes the PostgreSQL database with the basic schema

-- Create database user if not exists
DO
$do$
BEGIN
   IF NOT EXISTS (
      SELECT FROM pg_catalog.pg_roles 
      WHERE  rolname = 'freight_user') THEN
      CREATE ROLE freight_user LOGIN PASSWORD 'freight_pass_changeme';
   END IF;
END
$do$;

-- Grant necessary permissions
GRANT CREATE ON DATABASE freight_matching TO freight_user;
GRANT CONNECT ON DATABASE freight_matching TO freight_user;

-- Create basic schema for freight matching
\c freight_matching;

-- Set search path
SET search_path TO public;

-- Basic tables that Rails will manage through migrations
-- This is just to ensure the database is properly set up

-- Users table (will be created by Devise)
CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    email VARCHAR(255) NOT NULL UNIQUE,
    encrypted_password VARCHAR(255) NOT NULL,
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    phone VARCHAR(20),
    user_type VARCHAR(20) DEFAULT 'shipper', -- shipper, carrier, broker
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Carriers table
CREATE TABLE IF NOT EXISTS carriers (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id),
    company_name VARCHAR(255),
    mc_number VARCHAR(50),
    dot_number VARCHAR(50),
    equipment_type VARCHAR(50),
    current_latitude DECIMAL(10, 8),
    current_longitude DECIMAL(11, 8),
    status VARCHAR(20) DEFAULT 'available',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Loads table
CREATE TABLE IF NOT EXISTS loads (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id),
    pickup_address TEXT,
    pickup_latitude DECIMAL(10, 8),
    pickup_longitude DECIMAL(11, 8),
    delivery_address TEXT,
    delivery_latitude DECIMAL(10, 8),
    delivery_longitude DECIMAL(11, 8),
    weight DECIMAL(10, 2),
    equipment_type VARCHAR(50),
    rate DECIMAL(10, 2),
    status VARCHAR(20) DEFAULT 'posted',
    pickup_date DATE,
    delivery_date DATE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Load assignments table
CREATE TABLE IF NOT EXISTS load_assignments (
    id SERIAL PRIMARY KEY,
    load_id INTEGER REFERENCES loads(id),
    carrier_id INTEGER REFERENCES carriers(id),
    status VARCHAR(20) DEFAULT 'assigned',
    assigned_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    completed_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
CREATE INDEX IF NOT EXISTS idx_carriers_user_id ON carriers(user_id);
CREATE INDEX IF NOT EXISTS idx_loads_user_id ON loads(user_id);
CREATE INDEX IF NOT EXISTS idx_loads_status ON loads(status);
CREATE INDEX IF NOT EXISTS idx_load_assignments_load_id ON load_assignments(load_id);
CREATE INDEX IF NOT EXISTS idx_load_assignments_carrier_id ON load_assignments(carrier_id);

-- Grant permissions to freight_user
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO freight_user;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO freight_user;

-- Insert some sample data for testing
INSERT INTO users (email, encrypted_password, first_name, last_name, user_type) VALUES
('admin@freightmatch.com', '$2a$12$example_encrypted_password', 'System', 'Admin', 'admin'),
('shipper@example.com', '$2a$12$example_encrypted_password', 'John', 'Shipper', 'shipper'),
('carrier@example.com', '$2a$12$example_encrypted_password', 'Jane', 'Carrier', 'carrier')
ON CONFLICT (email) DO NOTHING;

COMMIT;