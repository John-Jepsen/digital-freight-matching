-- Digital Freight Matching Database Schema
-- This script initializes the PostgreSQL database with all required tables
-- Create database (if running separately)
-- CREATE DATABASE freight_matching;
-- Enable PostGIS extension for geographic operations
CREATE EXTENSION IF NOT EXISTS postgis;
-- Users table
CREATE TABLE users (
    id BIGSERIAL PRIMARY KEY,
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    phone_number VARCHAR(20),
    user_type VARCHAR(20) NOT NULL CHECK (
        user_type IN ('SHIPPER', 'CARRIER', 'BROKER', 'ADMIN')
    ),
    is_active BOOLEAN DEFAULT TRUE,
    email_verified BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
-- Carriers table
CREATE TABLE carriers (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT REFERENCES users(id) ON DELETE CASCADE,
    company_name VARCHAR(255) NOT NULL,
    dot_number VARCHAR(20) UNIQUE,
    mc_number VARCHAR(20) UNIQUE,
    insurance_expiry DATE,
    insurance_amount DECIMAL(12, 2),
    status VARCHAR(20) DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE', 'INACTIVE', 'SUSPENDED')),
    rating DECIMAL(3, 2) DEFAULT 0.00,
    total_deliveries INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
-- Shippers table
CREATE TABLE shippers (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT REFERENCES users(id) ON DELETE CASCADE,
    company_name VARCHAR(255) NOT NULL,
    business_type VARCHAR(100),
    payment_terms VARCHAR(50),
    credit_rating VARCHAR(10),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
-- Brokers table
CREATE TABLE brokers (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT REFERENCES users(id) ON DELETE CASCADE,
    company_name VARCHAR(255) NOT NULL,
    license_number VARCHAR(50),
    commission_rate DECIMAL(5, 2) DEFAULT 10.00,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
-- Equipment types table
CREATE TABLE equipment_types (
    id SERIAL PRIMARY KEY,
    name VARCHAR(50) UNIQUE NOT NULL,
    description TEXT,
    max_weight DECIMAL(10, 2),
    max_volume DECIMAL(10, 2)
);
-- Equipment table
CREATE TABLE equipment (
    id BIGSERIAL PRIMARY KEY,
    carrier_id BIGINT REFERENCES carriers(id) ON DELETE CASCADE,
    equipment_type_id INTEGER REFERENCES equipment_types(id),
    make VARCHAR(50),
    model VARCHAR(50),
    year INTEGER,
    plate_number VARCHAR(20),
    vin VARCHAR(17),
    capacity DECIMAL(10, 2),
    dimensions VARCHAR(50),
    status VARCHAR(20) DEFAULT 'AVAILABLE' CHECK (
        status IN (
            'AVAILABLE',
            'IN_USE',
            'MAINTENANCE',
            'OUT_OF_SERVICE'
        )
    ),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
-- Drivers table
CREATE TABLE drivers (
    id BIGSERIAL PRIMARY KEY,
    carrier_id BIGINT REFERENCES carriers(id) ON DELETE CASCADE,
    employee_id VARCHAR(50),
    license_number VARCHAR(50) UNIQUE NOT NULL,
    license_expiry DATE NOT NULL,
    certifications TEXT [],
    status VARCHAR(20) DEFAULT 'AVAILABLE' CHECK (
        status IN ('AVAILABLE', 'DRIVING', 'OFF_DUTY', 'INACTIVE')
    ),
    rating DECIMAL(3, 2) DEFAULT 0.00,
    total_miles INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
-- Locations table
CREATE TABLE locations (
    id BIGSERIAL PRIMARY KEY,
    address VARCHAR(500) NOT NULL,
    city VARCHAR(100) NOT NULL,
    state VARCHAR(50) NOT NULL,
    zip_code VARCHAR(10) NOT NULL,
    country VARCHAR(50) DEFAULT 'USA',
    latitude DECIMAL(10, 8),
    longitude DECIMAL(11, 8),
    facility_type VARCHAR(50),
    facility_name VARCHAR(255),
    contact_name VARCHAR(255),
    contact_phone VARCHAR(20),
    operating_hours TEXT,
    special_instructions TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
-- Create spatial index for locations
CREATE INDEX idx_locations_point ON locations USING GIST(ST_Point(longitude, latitude));
-- Load types table
CREATE TABLE load_types (
    id SERIAL PRIMARY KEY,
    name VARCHAR(50) UNIQUE NOT NULL,
    description TEXT,
    requires_special_equipment BOOLEAN DEFAULT FALSE
);
-- Loads table
CREATE TABLE loads (
    id BIGSERIAL PRIMARY KEY,
    shipper_id BIGINT REFERENCES shippers(id) ON DELETE CASCADE,
    broker_id BIGINT REFERENCES brokers(id) ON DELETE
    SET NULL,
        load_type_id INTEGER REFERENCES load_types(id),
        pickup_location_id BIGINT REFERENCES locations(id),
        delivery_location_id BIGINT REFERENCES locations(id),
        pickup_date TIMESTAMP NOT NULL,
        delivery_date TIMESTAMP NOT NULL,
        weight DECIMAL(10, 2),
        pallet_count INTEGER,
        volume DECIMAL(10, 2),
        commodity VARCHAR(255),
        special_requirements TEXT,
        offered_rate DECIMAL(10, 2) NOT NULL,
        negotiable BOOLEAN DEFAULT TRUE,
        status VARCHAR(20) DEFAULT 'POSTED' CHECK (
            status IN (
                'POSTED',
                'MATCHED',
                'BOOKED',
                'IN_TRANSIT',
                'DELIVERED',
                'CANCELLED',
                'EXPIRED'
            )
        ),
        equipment_type_required VARCHAR(50),
        distance_miles DECIMAL(8, 2),
        estimated_duration_hours DECIMAL(6, 2),
        load_number VARCHAR(50) UNIQUE,
        reference_number VARCHAR(100),
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
-- Routes table
CREATE TABLE routes (
    id BIGSERIAL PRIMARY KEY,
    load_id BIGINT REFERENCES loads(id) ON DELETE CASCADE,
    start_location_id BIGINT REFERENCES locations(id),
    end_location_id BIGINT REFERENCES locations(id),
    total_distance DECIMAL(8, 2) NOT NULL,
    estimated_time DECIMAL(6, 2) NOT NULL,
    fuel_cost DECIMAL(8, 2),
    toll_cost DECIMAL(8, 2),
    route_data JSONB,
    -- Store detailed route information
    has_backhaul BOOLEAN DEFAULT FALSE,
    backhaul_opportunity TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
-- Shipments table
CREATE TABLE shipments (
    id BIGSERIAL PRIMARY KEY,
    load_id BIGINT REFERENCES loads(id) ON DELETE CASCADE,
    carrier_id BIGINT REFERENCES carriers(id),
    driver_id BIGINT REFERENCES drivers(id),
    equipment_id BIGINT REFERENCES equipment(id),
    route_id BIGINT REFERENCES routes(id),
    bol_number VARCHAR(50) UNIQUE,
    pro_number VARCHAR(50),
    status VARCHAR(20) DEFAULT 'ASSIGNED' CHECK (
        status IN (
            'ASSIGNED',
            'PICKED_UP',
            'IN_TRANSIT',
            'DELIVERED',
            'CANCELLED'
        )
    ),
    pickup_confirmation TIMESTAMP,
    delivery_confirmation TIMESTAMP,
    current_latitude DECIMAL(10, 8),
    current_longitude DECIMAL(11, 8),
    last_location_update TIMESTAMP,
    completion_percentage DECIMAL(5, 2) DEFAULT 0.00,
    notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
-- Payments table
CREATE TABLE payments (
    id BIGSERIAL PRIMARY KEY,
    shipment_id BIGINT REFERENCES shipments(id) ON DELETE CASCADE,
    payer_id BIGINT REFERENCES users(id),
    payee_id BIGINT REFERENCES users(id),
    amount DECIMAL(12, 2) NOT NULL,
    currency VARCHAR(3) DEFAULT 'USD',
    payment_method VARCHAR(20) CHECK (
        payment_method IN ('CREDIT_CARD', 'ACH', 'WIRE', 'CHECK')
    ),
    status VARCHAR(20) DEFAULT 'PENDING' CHECK (
        status IN (
            'PENDING',
            'PROCESSING',
            'COMPLETED',
            'FAILED',
            'CANCELLED',
            'DISPUTED'
        )
    ),
    transaction_id VARCHAR(100),
    stripe_payment_intent_id VARCHAR(100),
    processed_at TIMESTAMP,
    due_date DATE,
    invoice_number VARCHAR(50),
    notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
-- Ratings table
CREATE TABLE ratings (
    id BIGSERIAL PRIMARY KEY,
    rater_id BIGINT REFERENCES users(id) ON DELETE CASCADE,
    rated_user_id BIGINT REFERENCES users(id) ON DELETE CASCADE,
    shipment_id BIGINT REFERENCES shipments(id) ON DELETE CASCADE,
    score INTEGER CHECK (
        score >= 1
        AND score <= 5
    ),
    rating_type VARCHAR(20) CHECK (
        rating_type IN (
            'CARRIER_TO_SHIPPER',
            'SHIPPER_TO_CARRIER',
            'BROKER_RATING'
        )
    ),
    comments TEXT,
    categories JSONB,
    -- Store category-specific ratings (punctuality, communication, etc.)
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
-- Notifications table
CREATE TABLE notifications (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT REFERENCES users(id) ON DELETE CASCADE,
    type VARCHAR(50) NOT NULL,
    title VARCHAR(255) NOT NULL,
    message TEXT NOT NULL,
    channel VARCHAR(20) CHECK (channel IN ('EMAIL', 'SMS', 'PUSH', 'IN_APP')),
    is_read BOOLEAN DEFAULT FALSE,
    metadata JSONB,
    sent_at TIMESTAMP,
    read_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
-- Load matches table (for tracking matching algorithm results)
CREATE TABLE load_matches (
    id BIGSERIAL PRIMARY KEY,
    load_id BIGINT REFERENCES loads(id) ON DELETE CASCADE,
    carrier_id BIGINT REFERENCES carriers(id) ON DELETE CASCADE,
    match_score DECIMAL(5, 2) NOT NULL,
    match_reasons TEXT [],
    algorithm_version VARCHAR(20),
    is_accepted BOOLEAN,
    responded_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
-- Audit log table
CREATE TABLE audit_logs (
    id BIGSERIAL PRIMARY KEY,
    table_name VARCHAR(50) NOT NULL,
    record_id BIGINT NOT NULL,
    action VARCHAR(20) NOT NULL CHECK (action IN ('INSERT', 'UPDATE', 'DELETE')),
    old_values JSONB,
    new_values JSONB,
    user_id BIGINT REFERENCES users(id),
    ip_address INET,
    user_agent TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
-- System configuration table
CREATE TABLE system_config (
    id SERIAL PRIMARY KEY,
    config_key VARCHAR(100) UNIQUE NOT NULL,
    config_value TEXT NOT NULL,
    description TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
-- Insert default equipment types
INSERT INTO equipment_types (name, description, max_weight, max_volume)
VALUES (
        'DRY_VAN',
        '53ft Dry Van Trailer',
        48000.00,
        3400.00
    ),
    (
        'REFRIGERATED',
        '53ft Refrigerated Trailer',
        45000.00,
        3200.00
    ),
    (
        'FLATBED',
        '48ft Flatbed Trailer',
        48000.00,
        NULL
    ),
    (
        'STEP_DECK',
        '48ft Step Deck Trailer',
        48000.00,
        NULL
    ),
    ('LOWBOY', '48ft Lowboy Trailer', 80000.00, NULL),
    (
        'TANKER',
        'Liquid Tanker Trailer',
        80000.00,
        9000.00
    ),
    ('BOX_TRUCK', '26ft Box Truck', 26000.00, 1700.00),
    (
        'STRAIGHT_TRUCK',
        'Straight Truck',
        33000.00,
        2500.00
    );
-- Insert default load types
INSERT INTO load_types (name, description, requires_special_equipment)
VALUES (
        'GENERAL_FREIGHT',
        'General freight shipments',
        FALSE
    ),
    (
        'REFRIGERATED',
        'Temperature controlled freight',
        TRUE
    ),
    ('HAZMAT', 'Hazardous materials', TRUE),
    (
        'OVERSIZED',
        'Oversized/overweight freight',
        TRUE
    ),
    (
        'AUTOMOTIVE',
        'Vehicles and automotive parts',
        TRUE
    ),
    (
        'CONSTRUCTION',
        'Construction materials and equipment',
        FALSE
    ),
    ('RETAIL', 'Retail and consumer goods', FALSE),
    (
        'FOOD_BEVERAGE',
        'Food and beverage products',
        TRUE
    );
-- Insert system configuration defaults
INSERT INTO system_config (config_key, config_value, description)
VALUES (
        'MATCHING_ALGORITHM_VERSION',
        '1.0',
        'Current version of the matching algorithm'
    ),
    (
        'MAX_DEADHEAD_PERCENTAGE',
        '15',
        'Maximum acceptable deadhead percentage for matches'
    ),
    (
        'DEFAULT_SEARCH_RADIUS',
        '250',
        'Default search radius in miles for load matching'
    ),
    (
        'PAYMENT_PROCESSING_FEE',
        '2.9',
        'Payment processing fee percentage'
    ),
    (
        'PLATFORM_COMMISSION_RATE',
        '8.0',
        'Default platform commission rate percentage'
    ),
    (
        'MAX_LOAD_AGE_HOURS',
        '72',
        'Maximum hours a load can remain active'
    ),
    (
        'MIN_CARRIER_RATING',
        '3.0',
        'Minimum carrier rating for automatic matching'
    ),
    (
        'NOTIFICATION_RETRY_ATTEMPTS',
        '3',
        'Number of retry attempts for failed notifications'
    );
-- Create indexes for better performance
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_type ON users(user_type);
CREATE INDEX idx_users_active ON users(is_active);
CREATE INDEX idx_carriers_status ON carriers(status);
CREATE INDEX idx_carriers_rating ON carriers(rating);
CREATE INDEX idx_carriers_dot ON carriers(dot_number);
CREATE INDEX idx_loads_status ON loads(status);
CREATE INDEX idx_loads_pickup_date ON loads(pickup_date);
CREATE INDEX idx_loads_delivery_date ON loads(delivery_date);
CREATE INDEX idx_loads_shipper ON loads(shipper_id);
CREATE INDEX idx_loads_created ON loads(created_at);
CREATE INDEX idx_shipments_status ON shipments(status);
CREATE INDEX idx_shipments_carrier ON shipments(carrier_id);
CREATE INDEX idx_shipments_load ON shipments(load_id);
CREATE INDEX idx_payments_status ON payments(status);
CREATE INDEX idx_payments_shipment ON payments(shipment_id);
CREATE INDEX idx_equipment_carrier ON equipment(carrier_id);
CREATE INDEX idx_equipment_status ON equipment(status);
CREATE INDEX idx_equipment_type ON equipment(equipment_type_id);
CREATE INDEX idx_drivers_carrier ON drivers(carrier_id);
CREATE INDEX idx_drivers_status ON drivers(status);
CREATE INDEX idx_drivers_license ON drivers(license_number);
CREATE INDEX idx_notifications_user ON notifications(user_id);
CREATE INDEX idx_notifications_read ON notifications(is_read);
CREATE INDEX idx_notifications_type ON notifications(type);
CREATE INDEX idx_load_matches_load ON load_matches(load_id);
CREATE INDEX idx_load_matches_carrier ON load_matches(carrier_id);
CREATE INDEX idx_load_matches_score ON load_matches(match_score);
-- Create function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column() RETURNS TRIGGER AS $$ BEGIN NEW.updated_at = CURRENT_TIMESTAMP;
RETURN NEW;
END;
$$ language 'plpgsql';
-- Create triggers to automatically update updated_at columns
CREATE TRIGGER update_users_updated_at BEFORE
UPDATE ON users FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_carriers_updated_at BEFORE
UPDATE ON carriers FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_shippers_updated_at BEFORE
UPDATE ON shippers FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_brokers_updated_at BEFORE
UPDATE ON brokers FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_equipment_updated_at BEFORE
UPDATE ON equipment FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_drivers_updated_at BEFORE
UPDATE ON drivers FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_loads_updated_at BEFORE
UPDATE ON loads FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_shipments_updated_at BEFORE
UPDATE ON shipments FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_payments_updated_at BEFORE
UPDATE ON payments FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_system_config_updated_at BEFORE
UPDATE ON system_config FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
-- Grant permissions (adjust as needed for your environment)
-- GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO freight_user;
-- GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO freight_user;
-- Insert sample admin user (password should be hashed in real implementation)
-- Password: admin123 (this should be properly hashed using bcrypt)
INSERT INTO users (
        email,
        password_hash,
        first_name,
        last_name,
        user_type,
        is_active,
        email_verified
    )
VALUES (
        'admin@freightmatch.com',
        '$2a$10$EXAMPLE_HASH_PLACEHOLDER',
        'System',
        'Administrator',
        'ADMIN',
        TRUE,
        TRUE
    );
COMMENT ON DATABASE freight_matching IS 'Digital Freight Matching Platform Database';
COMMENT ON TABLE users IS 'Core user accounts for all platform participants';
COMMENT ON TABLE carriers IS 'Carrier companies and their operational details';
COMMENT ON TABLE shippers IS 'Shipping companies posting freight loads';
COMMENT ON TABLE brokers IS 'Freight brokers facilitating transactions';
COMMENT ON TABLE loads IS 'Freight loads posted for transportation';
COMMENT ON TABLE shipments IS 'Active shipments being tracked';
COMMENT ON TABLE payments IS 'Payment transactions and invoicing';
COMMENT ON TABLE ratings IS 'User ratings and reviews system';
COMMENT ON TABLE equipment IS 'Carrier equipment and fleet management';
COMMENT ON TABLE drivers IS 'Driver information and certifications';
COMMENT ON TABLE locations IS 'Pickup and delivery location details';
COMMENT ON TABLE routes IS 'Optimized routing information';
COMMENT ON TABLE load_matches IS 'AI matching algorithm results';
COMMENT ON TABLE notifications IS 'System notifications and communications';
COMMENT ON TABLE audit_logs IS 'Complete audit trail for all system changes';