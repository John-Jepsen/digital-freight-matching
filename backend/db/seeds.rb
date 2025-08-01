# Seeds file for Digital Freight Matching Platform

puts "🌱 Seeding development data..."

# Create Admin User
admin = User.create!(
  email: 'admin@freightmatch.com',
  password: 'password123',
  password_confirmation: 'password123',
  first_name: 'Admin',
  last_name: 'User',
  user_type: 'admin',
  status: 'active',
  confirmed_at: Time.current
)

puts "✅ Created admin user: #{admin.email}"

# Create Shipper Users and Profiles
shipper_user = User.create!(
  email: 'shipper@example.com',
  password: 'password123',
  password_confirmation: 'password123',
  first_name: 'John',
  last_name: 'Smith',
  user_type: 'shipper',
  status: 'active',
  confirmed_at: Time.current
)

shipper_profile = shipper_user.shipper_profile
shipper_profile.update!(
  company_name: 'ABC Manufacturing Corp',
  industry: 'manufacturing',
  address_line1: '123 Industrial Blvd',
  city: 'Atlanta',
  state: 'GA',
  postal_code: '30309',
  phone: '4045551234',
  tax_id: '123456789',
  dot_number: 'DOT123456',
  credit_limit: 50000.00,
  shipping_volume_monthly: 150
)

puts "✅ Created shipper: #{shipper_profile.company_name}"

# Create Carrier Users and Profiles
carrier_user = User.create!(
  email: 'carrier@example.com',
  password: 'password123',
  password_confirmation: 'password123',
  first_name: 'Mike',
  last_name: 'Johnson',
  user_type: 'carrier',
  status: 'active',
  confirmed_at: Time.current
)

carrier_profile = carrier_user.carrier_profile
carrier_profile.update!(
  company_name: 'Johnson Trucking LLC',
  mc_number: 'MC123456',
  dot_number: '12345678',
  scac_code: 'JHTR',
  address_line1: '456 Highway 85',
  city: 'Birmingham',
  state: 'AL',
  postal_code: '35203',
  phone: '2055551234',
  fleet_size: 5,
  equipment_types: ['dry_van', 'refrigerated'].to_json,
  service_areas: ['AL', 'GA', 'FL', 'TN'].to_json,
  insurance_amount: 1000000.00,
  insurance_expiry: 1.year.from_now,
  operating_authority: 'interstate',
  safety_rating: 'satisfactory',
  is_verified: true,
  is_active: true
)

puts "✅ Created carrier: #{carrier_profile.company_name}"

# Create Driver
driver = carrier_profile.drivers.create!(
  driver_number: 'D001',
  first_name: 'Bob',
  last_name: 'Wilson',
  phone: '2055555678',
  email: 'bob.wilson@johnsontrucking.com',
  license_number: 'AL123456789',
  license_state: 'AL',
  license_expiry: 2.years.from_now,
  cdl_class: 'A',
  cdl_endorsements: 'H, N',
  medical_cert_expiry: 1.year.from_now,
  status: 'available',
  hire_date: 2.years.ago,
  is_hazmat_certified: true,
  is_team_driver: false,
  address_line1: '789 Truck Stop Rd',
  city: 'Birmingham',
  state: 'AL',
  postal_code: '35204'
)

puts "✅ Created driver: #{driver.full_name}"

# Create Vehicle
vehicle = carrier_profile.vehicles.create!(
  vehicle_number: 'T001',
  vin: '1HGCM82633A123456',
  make: 'Freightliner',
  model: 'Cascadia',
  year: 2020,
  equipment_type: 'dry_van',
  capacity_weight: 80000.00,
  length: 53.0,
  width: 8.5,
  height: 13.5,
  fuel_type: 'diesel',
  mpg: 6.5,
  status: 'active',
  maintenance_due_date: 3.months.from_now,
  inspection_due_date: 6.months.from_now,
  registration_expiry: 1.year.from_now,
  insurance_expiry: 1.year.from_now,
  is_temperature_controlled: false,
  is_hazmat_certified: true,
  is_team_capable: false
)

puts "✅ Created vehicle: #{vehicle.display_name}"

# Assign driver to vehicle
driver.assign_to_vehicle(vehicle)
puts "✅ Assigned driver to vehicle"

# Create Sample Loads
load1 = shipper_profile.loads.create!(
  commodity: 'Auto Parts',
  description: 'Shipment of automotive components for assembly plant',
  weight: 25000.00,
  dimensions: '48 x 8 x 8',
  pickup_address_line1: '100 Manufacturing Dr',
  pickup_city: 'Atlanta',
  pickup_state: 'GA',
  pickup_postal_code: '30309',
  pickup_date: 2.days.from_now,
  pickup_contact_name: 'Sarah Jones',
  pickup_contact_phone: '4045559876',
  delivery_address_line1: '200 Assembly Ln',
  delivery_city: 'Nashville',
  delivery_state: 'TN',
  delivery_postal_code: '37201',
  delivery_date: 4.days.from_now,
  delivery_contact_name: 'Tom Brown',
  delivery_contact_phone: '6155551234',
  equipment_type: 'dry_van',
  rate: 1500.00,
  fuel_surcharge: 75.00,
  payment_terms: 30,
  requires_tracking: true,
  is_expedited: false,
  expires_at: 1.day.from_now
)

puts "✅ Created load: #{load1.reference_number}"

load2 = shipper_profile.loads.create!(
  commodity: 'Fresh Produce',
  description: 'Temperature-controlled shipment of fresh vegetables',
  weight: 30000.00,
  pickup_address_line1: '500 Farm Rd',
  pickup_city: 'Valdosta',
  pickup_state: 'GA',
  pickup_postal_code: '31601',
  pickup_date: 1.day.from_now,
  delivery_address_line1: '300 Market St',
  delivery_city: 'Jacksonville',
  delivery_state: 'FL',
  delivery_postal_code: '32202',
  delivery_date: 2.days.from_now,
  equipment_type: 'refrigerated',
  rate: 1200.00,
  temperature_controlled: true,
  temperature_min: 32,
  temperature_max: 38,
  requires_tracking: true,
  is_expedited: true,
  expires_at: 12.hours.from_now
)

puts "✅ Created load: #{load2.reference_number}"

puts "🎉 Seeding completed successfully!"
puts ""
puts "🔑 Login credentials:"
puts "Admin: admin@freightmatch.com / password123"
puts "Shipper: shipper@example.com / password123"
puts "Carrier: carrier@example.com / password123"
