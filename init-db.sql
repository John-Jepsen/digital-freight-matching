-- Digital Freight Matching Database Schema - Rails Edition
-- This script initializes the PostgreSQL database following Rails conventions
-- Compatible with Rails 8.0+ and ActiveRecord patterns
-- Create database (if running separately)
-- CREATE DATABASE freight_matching_development;
-- CREATE DATABASE freight_matching_test;
-- CREATE DATABASE freight_matching_production;
-- Enable PostGIS extension for geographic operations
CREATE EXTENSION IF NOT EXISTS postgis;
-- Users table (Rails conventions with encrypted_password)
CREATE TABLE users (
    id BIGSERIAL PRIMARY KEY,
    email VARCHAR(255) UNIQUE NOT NULL,
    encrypted_password VARCHAR(255) NOT NULL,
    -- Devise convention
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    phone_number VARCHAR(20),
    user_type VARCHAR(20) NOT NULL CHECK (
        user_type IN ('shipper', 'carrier', 'broker', 'admin')
    ),
    active BOOLEAN DEFAULT TRUE,
    -- Rails boolean convention
    email_verified BOOLEAN DEFAULT FALSE,
    confirmation_token VARCHAR(255),
    -- Devise confirmable
    confirmed_at TIMESTAMP,
    confirmation_sent_at TIMESTAMP,
    reset_password_token VARCHAR(255),
    -- Devise recoverable
    reset_password_sent_at TIMESTAMP,
    remember_created_at TIMESTAMP,
    -- Devise rememberable
    sign_in_count INTEGER DEFAULT 0,
    -- Devise trackable
    current_sign_in_at TIMESTAMP,
    last_sign_in_at TIMESTAMP,
    current_sign_in_ip INET,
    last_sign_in_ip INET,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);
-- Carrier Profiles table (Rails polymorphic association pattern)
CREATE TABLE carrier_profiles (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT REFERENCES users(id) ON DELETE CASCADE,
    company_name VARCHAR(255) NOT NULL,
    dot_number VARCHAR(20) UNIQUE,
    mc_number VARCHAR(20) UNIQUE,
    insurance_info TEXT,
    -- Rails text type
    status VARCHAR(20) DEFAULT 'active' CHECK (status IN ('active', 'inactive', 'suspended')),
    rating DECIMAL(3, 2) DEFAULT 0.00,
    total_deliveries INTEGER DEFAULT 0,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);
-- Shipper Profiles table
CREATE TABLE shipper_profiles (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT REFERENCES users(id) ON DELETE CASCADE,
    company_name VARCHAR(255) NOT NULL,
    business_type VARCHAR(100),
    payment_terms VARCHAR(50),
    credit_rating DECIMAL(3, 1),
    -- Numeric rating instead of string
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);
-- Broker Profiles table
CREATE TABLE broker_profiles (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT REFERENCES users(id) ON DELETE CASCADE,
    company_name VARCHAR(255) NOT NULL,
    license_number VARCHAR(50),
    commission_rate DECIMAL(5, 2) DEFAULT 10.00,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);
-- Equipment types table
CREATE TABLE equipment_types (
    id SERIAL PRIMARY KEY,
    name VARCHAR(50) UNIQUE NOT NULL,
    description TEXT,
    max_weight DECIMAL(10, 2),
    max_volume DECIMAL(10, 2)
);
-- Equipment table (Rails associations)
CREATE TABLE equipment (
    id BIGSERIAL PRIMARY KEY,
    carrier_profile_id BIGINT REFERENCES carrier_profiles(id) ON DELETE CASCADE,
    equipment_type_id INTEGER REFERENCES equipment_types(id),
    make VARCHAR(50),
    model VARCHAR(50),
    year INTEGER,
    plate_number VARCHAR(20),
    vin VARCHAR(17),
    capacity DECIMAL(10, 2),
    dimensions VARCHAR(50),
    status VARCHAR(20) DEFAULT 'available' CHECK (
        status IN (
            'available',
            'in_use',
            'maintenance',
            'out_of_service'
        )
    ),
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);
-- Drivers table
CREATE TABLE drivers (
    id BIGSERIAL PRIMARY KEY,
    carrier_profile_id BIGINT REFERENCES carrier_profiles(id) ON DELETE CASCADE,
    employee_id VARCHAR(50),
    license_number VARCHAR(50) UNIQUE NOT NULL,
    license_expiry DATE NOT NULL,
    certifications TEXT,
    -- Rails will serialize arrays as text
    status VARCHAR(20) DEFAULT 'available' CHECK (
        status IN ('available', 'driving', 'off_duty', 'inactive')
    ),
    rating DECIMAL(3, 2) DEFAULT 0.00,
    total_miles INTEGER DEFAULT 0,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
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
-- Loads table (Rails conventions with snake_case)
CREATE TABLE loads (
    id BIGSERIAL PRIMARY KEY,
    shipper_profile_id BIGINT REFERENCES shipper_profiles(id) ON DELETE CASCADE,
    broker_profile_id BIGINT REFERENCES broker_profiles(id) ON DELETE
    SET NULL,
        load_type_id INTEGER REFERENCES load_types(id),
        pickup_location_id BIGINT REFERENCES locations(id),
        delivery_location_id BIGINT REFERENCES locations(id),
        pickup_time TIMESTAMP NOT NULL,
        -- Rails datetime convention
        delivery_time TIMESTAMP NOT NULL,
        weight DECIMAL(10, 2),
        pallet_count INTEGER,
        volume DECIMAL(10, 2),
        commodity VARCHAR(255),
        special_requirements TEXT,
        offered_rate DECIMAL(10, 2) NOT NULL,
        negotiable BOOLEAN DEFAULT TRUE,
        status VARCHAR(20) DEFAULT 'posted' CHECK (
            status IN (
                'posted',
                'matching',
                'matched',
                'booked',
                'in_transit',
                'delayed',
                'delivered',
                'payment_pending',
                'completed',
                'cancelled',
                'expired'
            )
        ),
        equipment_type_required VARCHAR(50),
        distance_miles DECIMAL(8, 2),
        estimated_duration_hours DECIMAL(6, 2),
        load_number VARCHAR(50) UNIQUE,
        reference_number VARCHAR(100),
        aasm_state VARCHAR(20) DEFAULT 'posted',
        -- AASM state machine column
        created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
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
-- Shipments table (Rails associations)
CREATE TABLE shipments (
    id BIGSERIAL PRIMARY KEY,
    load_id BIGINT REFERENCES loads(id) ON DELETE CASCADE,
    carrier_profile_id BIGINT REFERENCES carrier_profiles(id),
    driver_id BIGINT REFERENCES drivers(id),
    equipment_id BIGINT REFERENCES equipment(id),
    route_id BIGINT REFERENCES routes(id),
    bol_number VARCHAR(50) UNIQUE,
    pro_number VARCHAR(50),
    status VARCHAR(20) DEFAULT 'assigned' CHECK (
        status IN (
            'assigned',
            'picked_up',
            'in_transit',
            'delivered',
            'cancelled'
        )
    ),
    pickup_confirmed_at TIMESTAMP,
    -- Rails timestamp naming
    delivery_confirmed_at TIMESTAMP,
    current_latitude DECIMAL(10, 8),
    current_longitude DECIMAL(11, 8),
    last_location_update TIMESTAMP,
    completion_percentage DECIMAL(5, 2) DEFAULT 0.00,
    notes TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);
-- Payments table (Rails money-rails compatible)
CREATE TABLE payments (
    id BIGSERIAL PRIMARY KEY,
    shipment_id BIGINT REFERENCES shipments(id) ON DELETE CASCADE,
    payer_id BIGINT REFERENCES users(id),
    payee_id BIGINT REFERENCES users(id),
    amount_cents BIGINT NOT NULL,
    -- money-rails uses cents
    currency VARCHAR(3) DEFAULT 'USD',
    payment_method VARCHAR(20) CHECK (
        payment_method IN ('credit_card', 'ach', 'wire', 'check')
    ),
    status VARCHAR(20) DEFAULT 'pending' CHECK (
        status IN (
            'pending',
            'processing',
            'completed',
            'failed',
            'cancelled',
            'disputed'
        )
    ),
    stripe_payment_intent_id VARCHAR(100),
    -- Stripe integration
    stripe_charge_id VARCHAR(100),
    processed_at TIMESTAMP,
    due_date DATE,
    invoice_number VARCHAR(50),
    notes TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);
-- Ratings table (Rails polymorphic associations)
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
            'carrier_to_shipper',
            'shipper_to_carrier',
            'broker_rating'
        )
    ),
    comments TEXT,
    categories JSONB,
    -- Store category-specific ratings (punctuality, communication, etc.)
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);
-- Notifications table (Rails conventions)
CREATE TABLE notifications (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT REFERENCES users(id) ON DELETE CASCADE,
    notification_type VARCHAR(50) NOT NULL,
    -- Rails enum naming
    title VARCHAR(255) NOT NULL,
    message TEXT NOT NULL,
    channel VARCHAR(20) CHECK (channel IN ('email', 'sms', 'push', 'in_app')),
    read BOOLEAN DEFAULT FALSE,
    -- Rails boolean naming
    metadata JSONB,
    sent_at TIMESTAMP,
    read_at TIMESTAMP,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);
-- Load matches table (for tracking matching algorithm results)
CREATE TABLE load_matches (
    id BIGSERIAL PRIMARY KEY,
    load_id BIGINT REFERENCES loads(id) ON DELETE CASCADE,
    carrier_profile_id BIGINT REFERENCES carrier_profiles(id) ON DELETE CASCADE,
    match_score DECIMAL(5, 2) NOT NULL,
    match_reasons TEXT,
    -- Rails serialization
    algorithm_version VARCHAR(20),
    accepted BOOLEAN,
    -- Rails boolean naming
    responded_at TIMESTAMP,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
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
CREATE TABLE system_configs (
    id SERIAL PRIMARY KEY,
    config_key VARCHAR(100) UNIQUE NOT NULL,
    config_value TEXT NOT NULL,
    description TEXT,
    active BOOLEAN DEFAULT TRUE,
    -- Rails boolean naming
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);
-- Active Storage tables (Rails file attachments)
CREATE TABLE active_storage_blobs (
    id BIGSERIAL PRIMARY KEY,
    key VARCHAR(255) NOT NULL,
    filename VARCHAR(255) NOT NULL,
    content_type VARCHAR(255),
    metadata TEXT,
    service_name VARCHAR(255) NOT NULL,
    byte_size BIGINT NOT NULL,
    checksum VARCHAR(255) NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE active_storage_attachments (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    record_type VARCHAR(255) NOT NULL,
    record_id BIGINT NOT NULL,
    blob_id BIGINT NOT NULL REFERENCES active_storage_blobs(id),
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE active_storage_variant_records (
    id BIGSERIAL PRIMARY KEY,
    blob_id BIGINT NOT NULL REFERENCES active_storage_blobs(id),
    variation_digest VARCHAR(255) NOT NULL
);
-- ActionText tables (Rails rich text)
CREATE TABLE action_text_rich_texts (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    body TEXT,
    record_type VARCHAR(255) NOT NULL,
    record_id BIGINT NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);
-- Insert default equipment types (Rails snake_case)
INSERT INTO equipment_types (name, description, max_weight, max_volume)
VALUES (
        'dry_van',
        '53ft Dry Van Trailer',
        48000.00,
        3400.00
    ),
    (
        'refrigerated',
        '53ft Refrigerated Trailer',
        45000.00,
        3200.00
    ),
    (
        'flatbed',
        '48ft Flatbed Trailer',
        48000.00,
        NULL
    ),
    (
        'step_deck',
        '48ft Step Deck Trailer',
        48000.00,
        NULL
    ),
    ('lowboy', '48ft Lowboy Trailer', 80000.00, NULL),
    (
        'tanker',
        'Liquid Tanker Trailer',
        80000.00,
        9000.00
    ),
    ('box_truck', '26ft Box Truck', 26000.00, 1700.00),
    (
        'straight_truck',
        'Straight Truck',
        33000.00,
        2500.00
    );
-- Insert default load types
INSERT INTO load_types (name, description, requires_special_equipment)
VALUES (
        'general_freight',
        'General freight shipments',
        FALSE
    ),
    (
        'refrigerated',
        'Temperature controlled freight',
        TRUE
    ),
    ('hazmat', 'Hazardous materials', TRUE),
    (
        'oversized',
        'Oversized/overweight freight',
        TRUE
    ),
    (
        'automotive',
        'Vehicles and automotive parts',
        TRUE
    ),
    (
        'construction',
        'Construction materials and equipment',
        FALSE
    ),
    ('retail', 'Retail and consumer goods', FALSE),
    (
        'food_beverage',
        'Food and beverage products',
        TRUE
    );
-- Insert system configuration defaults
INSERT INTO system_configs (config_key, config_value, description)
VALUES (
        'matching_algorithm_version',
        '1.0',
        'Current version of the matching algorithm'
    ),
    (
        'max_deadhead_percentage',
        '15',
        'Maximum acceptable deadhead percentage for matches'
    ),
    (
        'default_search_radius',
        '250',
        'Default search radius in miles for load matching'
    ),
    (
        'payment_processing_fee',
        '2.9',
        'Payment processing fee percentage'
    ),
    (
        'platform_commission_rate',
        '8.0',
        'Default platform commission rate percentage'
    ),
    (
        'max_load_age_hours',
        '72',
        'Maximum hours a load can remain active'
    ),
    (
        'min_carrier_rating',
        '3.0',
        'Minimum carrier rating for automatic matching'
    ),
    (
        'notification_retry_attempts',
        '3',
        'Number of retry attempts for failed notifications'
    );
-- Create indexes for better performance (Rails naming conventions)
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_user_type ON users(user_type);
CREATE INDEX idx_users_active ON users(active);
CREATE INDEX idx_users_confirmation_token ON users(confirmation_token);
CREATE INDEX idx_users_reset_password_token ON users(reset_password_token);
CREATE INDEX idx_carrier_profiles_status ON carrier_profiles(status);
CREATE INDEX idx_carrier_profiles_rating ON carrier_profiles(rating);
CREATE INDEX idx_carrier_profiles_dot_number ON carrier_profiles(dot_number);
CREATE INDEX idx_carrier_profiles_user_id ON carrier_profiles(user_id);
CREATE INDEX idx_shipper_profiles_user_id ON shipper_profiles(user_id);
CREATE INDEX idx_broker_profiles_user_id ON broker_profiles(user_id);
CREATE INDEX idx_loads_status ON loads(status);
CREATE INDEX idx_loads_aasm_state ON loads(aasm_state);
CREATE INDEX idx_loads_pickup_time ON loads(pickup_time);
CREATE INDEX idx_loads_delivery_time ON loads(delivery_time);
CREATE INDEX idx_loads_shipper_profile_id ON loads(shipper_profile_id);
CREATE INDEX idx_loads_created_at ON loads(created_at);
CREATE INDEX idx_shipments_status ON shipments(status);
CREATE INDEX idx_shipments_carrier_profile_id ON shipments(carrier_profile_id);
CREATE INDEX idx_shipments_load_id ON shipments(load_id);
CREATE INDEX idx_payments_status ON payments(status);
CREATE INDEX idx_payments_shipment_id ON payments(shipment_id);
CREATE INDEX idx_payments_stripe_payment_intent_id ON payments(stripe_payment_intent_id);
CREATE INDEX idx_equipment_carrier_profile_id ON equipment(carrier_profile_id);
CREATE INDEX idx_equipment_status ON equipment(status);
CREATE INDEX idx_equipment_equipment_type_id ON equipment(equipment_type_id);
CREATE INDEX idx_drivers_carrier_profile_id ON drivers(carrier_profile_id);
CREATE INDEX idx_drivers_status ON drivers(status);
CREATE INDEX idx_drivers_license_number ON drivers(license_number);
CREATE INDEX idx_notifications_user_id ON notifications(user_id);
CREATE INDEX idx_notifications_read ON notifications(read);
CREATE INDEX idx_notifications_notification_type ON notifications(notification_type);
CREATE INDEX idx_load_matches_load_id ON load_matches(load_id);
CREATE INDEX idx_load_matches_carrier_profile_id ON load_matches(carrier_profile_id);
CREATE INDEX idx_load_matches_match_score ON load_matches(match_score);
-- Active Storage indexes
CREATE INDEX idx_active_storage_blobs_key ON active_storage_blobs(key);
CREATE INDEX idx_active_storage_attachments_record ON active_storage_attachments(record_type, record_id, name, blob_id);
CREATE INDEX idx_active_storage_variant_records_blob ON active_storage_variant_records(blob_id, variation_digest);
-- ActionText indexes  
CREATE INDEX idx_action_text_rich_texts_record ON action_text_rich_texts(record_type, record_id, name);
-- Create function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column() RETURNS TRIGGER AS $$ BEGIN NEW.updated_at = CURRENT_TIMESTAMP;
RETURN NEW;
END;
$$ language 'plpgsql';
-- Create triggers to automatically update updated_at columns (Rails convention)
CREATE TRIGGER update_users_updated_at BEFORE
UPDATE ON users FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_carrier_profiles_updated_at BEFORE
UPDATE ON carrier_profiles FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_shipper_profiles_updated_at BEFORE
UPDATE ON shipper_profiles FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_broker_profiles_updated_at BEFORE
UPDATE ON broker_profiles FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
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
CREATE TRIGGER update_ratings_updated_at BEFORE
UPDATE ON ratings FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_notifications_updated_at BEFORE
UPDATE ON notifications FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_load_matches_updated_at BEFORE
UPDATE ON load_matches FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_system_configs_updated_at BEFORE
UPDATE ON system_configs FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_action_text_rich_texts_updated_at BEFORE
UPDATE ON action_text_rich_texts FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
-- Insert sample admin user (Devise encrypted password format)
-- Password: admin123 (this should be properly hashed using Devise/bcrypt)
INSERT INTO users (
        email,
        encrypted_password,
        first_name,
        last_name,
        user_type,
        active,
        email_verified,
        confirmed_at
    )
VALUES (
        'admin@freightmatch.com',
        '$2a$12$EXAMPLE_BCRYPT_HASH_FOR_DEVISE',
        'System',
        'Administrator',
        'admin',
        TRUE,
        TRUE,
        CURRENT_TIMESTAMP
    );
-- Database comments (Rails-style documentation)
COMMENT ON DATABASE freight_matching IS 'Digital Freight Matching Platform Database - Rails Edition';
COMMENT ON TABLE users IS 'Devise-based user accounts for all platform participants';
COMMENT ON TABLE carrier_profiles IS 'Carrier companies and their operational details';
COMMENT ON TABLE shipper_profiles IS 'Shipping companies posting freight loads';
COMMENT ON TABLE broker_profiles IS 'Freight brokers facilitating transactions';
COMMENT ON TABLE loads IS 'Freight loads with AASM state machine management';
COMMENT ON TABLE shipments IS 'Active shipments being tracked with real-time updates';
COMMENT ON TABLE payments IS 'Stripe-integrated payment transactions with money-rails';
COMMENT ON TABLE ratings IS 'User ratings and reviews system';
COMMENT ON TABLE equipment IS 'Carrier equipment and fleet management';
COMMENT ON TABLE drivers IS 'Driver information and certifications';
COMMENT ON TABLE locations IS 'Pickup and delivery location details with PostGIS';
COMMENT ON TABLE routes IS 'Optimized routing information';
COMMENT ON TABLE load_matches IS 'Ruby AI matching algorithm results';
COMMENT ON TABLE notifications IS 'ActionCable-powered notifications and communications';
COMMENT ON TABLE audit_logs IS 'Complete audit trail for all system changes';
COMMENT ON TABLE active_storage_blobs IS 'Rails Active Storage file attachments';
COMMENT ON TABLE active_storage_attachments IS 'Rails Active Storage polymorphic attachments';
COMMENT ON TABLE action_text_rich_texts IS 'Rails ActionText rich content storage';