# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.1].define(version: 2025_08_29_000001) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "cargo_details", force: :cascade do |t|
    t.bigint "load_id", null: false
    t.string "item_name", null: false
    t.text "item_description"
    t.integer "quantity", null: false
    t.string "unit_type", null: false
    t.decimal "weight_per_unit", precision: 8, scale: 2
    t.decimal "total_weight", precision: 8, scale: 2
    t.string "dimensions"
    t.decimal "volume", precision: 10, scale: 3
    t.decimal "value", precision: 10, scale: 2
    t.string "commodity_class"
    t.string "hazmat_class"
    t.string "nmfc_code"
    t.string "packaging_type"
    t.text "special_handling"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["commodity_class"], name: "index_cargo_details_on_commodity_class"
    t.index ["hazmat_class"], name: "index_cargo_details_on_hazmat_class"
    t.index ["load_id"], name: "index_cargo_details_on_load_id"
    t.index ["unit_type"], name: "index_cargo_details_on_unit_type"
  end

  create_table "carriers", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "company_name", null: false
    t.text "company_description"
    t.string "mc_number", null: false
    t.string "dot_number", null: false
    t.string "scac_code"
    t.string "address_line1"
    t.string "address_line2"
    t.string "city"
    t.string "state"
    t.string "postal_code"
    t.string "country", default: "US"
    t.decimal "latitude", precision: 10, scale: 6
    t.decimal "longitude", precision: 10, scale: 6
    t.string "phone"
    t.string "website"
    t.integer "fleet_size", default: 1
    t.text "equipment_types"
    t.text "service_areas"
    t.decimal "insurance_amount", precision: 12, scale: 2
    t.date "insurance_expiry"
    t.string "operating_authority"
    t.string "safety_rating", default: "satisfactory"
    t.boolean "is_verified", default: false
    t.boolean "is_active", default: true
    t.text "preferred_lanes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["company_name"], name: "index_carriers_on_company_name"
    t.index ["dot_number"], name: "index_carriers_on_dot_number", unique: true
    t.index ["is_active"], name: "index_carriers_on_is_active"
    t.index ["is_verified"], name: "index_carriers_on_is_verified"
    t.index ["latitude", "longitude"], name: "index_carriers_on_latitude_and_longitude"
    t.index ["mc_number"], name: "index_carriers_on_mc_number", unique: true
    t.index ["safety_rating"], name: "index_carriers_on_safety_rating"
    t.index ["scac_code"], name: "index_carriers_on_scac_code", unique: true
    t.index ["user_id"], name: "index_carriers_on_user_id"
  end

  create_table "drivers", force: :cascade do |t|
    t.bigint "user_id"
    t.bigint "carrier_id", null: false
    t.bigint "vehicle_id"
    t.string "driver_number", null: false
    t.string "first_name", null: false
    t.string "last_name", null: false
    t.string "phone"
    t.string "email"
    t.string "license_number", null: false
    t.string "license_state", null: false
    t.date "license_expiry", null: false
    t.string "cdl_class", null: false
    t.string "cdl_endorsements"
    t.date "medical_cert_expiry", null: false
    t.string "status", default: "available", null: false
    t.date "hire_date"
    t.date "termination_date"
    t.boolean "is_team_driver", default: false
    t.boolean "is_hazmat_certified", default: false
    t.boolean "is_owner_operator", default: false
    t.string "emergency_contact_name"
    t.string "emergency_contact_phone"
    t.string "address_line1"
    t.string "address_line2"
    t.string "city"
    t.string "state"
    t.string "postal_code"
    t.string "country", default: "US"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["carrier_id", "driver_number"], name: "index_drivers_on_carrier_id_and_driver_number", unique: true
    t.index ["carrier_id"], name: "index_drivers_on_carrier_id"
    t.index ["is_hazmat_certified"], name: "index_drivers_on_is_hazmat_certified"
    t.index ["is_team_driver"], name: "index_drivers_on_is_team_driver"
    t.index ["license_expiry"], name: "index_drivers_on_license_expiry"
    t.index ["license_number", "license_state"], name: "index_drivers_on_license_number_and_license_state", unique: true
    t.index ["medical_cert_expiry"], name: "index_drivers_on_medical_cert_expiry"
    t.index ["status"], name: "index_drivers_on_status"
    t.index ["user_id"], name: "index_drivers_on_user_id"
    t.index ["vehicle_id"], name: "index_drivers_on_vehicle_id"
  end

  create_table "load_assignments", id: :serial, force: :cascade do |t|
    t.integer "load_id"
    t.integer "carrier_id"
    t.string "status", limit: 20, default: "assigned"
    t.datetime "assigned_at", precision: nil, default: -> { "CURRENT_TIMESTAMP" }
    t.datetime "completed_at", precision: nil
    t.datetime "created_at", precision: nil, default: -> { "CURRENT_TIMESTAMP" }
    t.datetime "updated_at", precision: nil, default: -> { "CURRENT_TIMESTAMP" }
    t.index ["carrier_id"], name: "idx_load_assignments_carrier_id"
    t.index ["load_id"], name: "idx_load_assignments_load_id"
  end

  create_table "load_requirements", force: :cascade do |t|
    t.bigint "load_id", null: false
    t.string "requirement_type", null: false
    t.text "requirement_value"
    t.boolean "is_mandatory", default: true, null: false
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["is_mandatory"], name: "index_load_requirements_on_is_mandatory"
    t.index ["load_id", "requirement_type"], name: "index_load_requirements_on_load_id_and_requirement_type"
    t.index ["load_id"], name: "index_load_requirements_on_load_id"
    t.index ["requirement_type"], name: "index_load_requirements_on_requirement_type"
  end

  create_table "loads", force: :cascade do |t|
    t.bigint "shipper_id", null: false
    t.string "reference_number", null: false
    t.string "status", default: "posted", null: false
    t.string "load_type", null: false
    t.string "commodity", null: false
    t.text "description"
    t.decimal "weight", precision: 8, scale: 2
    t.string "dimensions"
    t.text "special_instructions"
    t.string "pickup_address_line1", null: false
    t.string "pickup_address_line2"
    t.string "pickup_city", null: false
    t.string "pickup_state", null: false
    t.string "pickup_postal_code", null: false
    t.string "pickup_country", default: "US"
    t.decimal "pickup_latitude", precision: 10, scale: 6
    t.decimal "pickup_longitude", precision: 10, scale: 6
    t.date "pickup_date", null: false
    t.time "pickup_time_window_start"
    t.time "pickup_time_window_end"
    t.string "pickup_contact_name"
    t.string "pickup_contact_phone"
    t.string "delivery_address_line1", null: false
    t.string "delivery_address_line2"
    t.string "delivery_city", null: false
    t.string "delivery_state", null: false
    t.string "delivery_postal_code", null: false
    t.string "delivery_country", default: "US"
    t.decimal "delivery_latitude", precision: 10, scale: 6
    t.decimal "delivery_longitude", precision: 10, scale: 6
    t.date "delivery_date", null: false
    t.time "delivery_time_window_start"
    t.time "delivery_time_window_end"
    t.string "delivery_contact_name"
    t.string "delivery_contact_phone"
    t.string "equipment_type", null: false
    t.decimal "rate", precision: 10, scale: 2, null: false
    t.string "rate_type", default: "flat", null: false
    t.decimal "mileage", precision: 8, scale: 2
    t.decimal "estimated_distance", precision: 8, scale: 2
    t.decimal "fuel_surcharge", precision: 6, scale: 2, default: "0.0"
    t.decimal "accessorial_charges", precision: 8, scale: 2, default: "0.0"
    t.decimal "total_rate", precision: 10, scale: 2
    t.string "currency", default: "USD"
    t.integer "payment_terms", default: 30
    t.boolean "requires_tracking", default: true
    t.boolean "requires_signature", default: false
    t.boolean "is_hazmat", default: false
    t.boolean "is_expedited", default: false
    t.boolean "is_team_driver", default: false
    t.boolean "temperature_controlled", default: false
    t.integer "temperature_min"
    t.integer "temperature_max"
    t.datetime "posted_at"
    t.datetime "expires_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["delivery_date"], name: "index_loads_on_delivery_date"
    t.index ["delivery_latitude", "delivery_longitude"], name: "index_loads_on_delivery_latitude_and_delivery_longitude"
    t.index ["delivery_state"], name: "index_loads_on_delivery_state"
    t.index ["equipment_type"], name: "index_loads_on_equipment_type"
    t.index ["expires_at"], name: "index_loads_on_expires_at"
    t.index ["is_expedited"], name: "index_loads_on_is_expedited"
    t.index ["is_hazmat"], name: "index_loads_on_is_hazmat"
    t.index ["pickup_date"], name: "index_loads_on_pickup_date"
    t.index ["pickup_latitude", "pickup_longitude"], name: "index_loads_on_pickup_latitude_and_pickup_longitude"
    t.index ["pickup_state"], name: "index_loads_on_pickup_state"
    t.index ["posted_at"], name: "index_loads_on_posted_at"
    t.index ["shipper_id", "reference_number"], name: "index_loads_on_shipper_id_and_reference_number", unique: true
    t.index ["shipper_id"], name: "index_loads_on_shipper_id"
    t.index ["status"], name: "index_loads_on_status"
    t.index ["temperature_controlled"], name: "index_loads_on_temperature_controlled"
  end

  create_table "locations", force: :cascade do |t|
    t.string "name", null: false
    t.string "address_line1", null: false
    t.string "address_line2"
    t.string "city", null: false
    t.string "state", null: false
    t.string "postal_code", null: false
    t.string "country", default: "US"
    t.decimal "latitude", precision: 10, scale: 6
    t.decimal "longitude", precision: 10, scale: 6
    t.string "location_type", null: false
    t.string "contact_name"
    t.string "contact_phone"
    t.string "contact_email"
    t.text "hours_of_operation"
    t.text "special_instructions"
    t.string "facility_type"
    t.string "dock_type"
    t.text "equipment_available"
    t.boolean "is_active", default: true
    t.string "timezone"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["city", "state"], name: "index_locations_on_city_and_state"
    t.index ["is_active"], name: "index_locations_on_is_active"
    t.index ["latitude", "longitude"], name: "index_locations_on_latitude_and_longitude"
    t.index ["location_type"], name: "index_locations_on_location_type"
    t.index ["state"], name: "index_locations_on_state"
  end

  create_table "matches", force: :cascade do |t|
    t.bigint "load_id", null: false
    t.bigint "carrier_id", null: false
    t.string "status", default: "pending", null: false
    t.decimal "match_score", precision: 5, scale: 2, default: "0.0"
    t.decimal "rate_offered", precision: 10, scale: 2
    t.decimal "rate_accepted", precision: 10, scale: 2
    t.datetime "estimated_pickup_time"
    t.datetime "estimated_delivery_time"
    t.decimal "distance_to_pickup", precision: 8, scale: 2
    t.decimal "fuel_cost_estimate", precision: 8, scale: 2
    t.decimal "margin_estimate", precision: 8, scale: 2
    t.text "notes"
    t.datetime "matched_at"
    t.datetime "accepted_at"
    t.datetime "rejected_at"
    t.datetime "expired_at"
    t.string "rejection_reason"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["accepted_at"], name: "index_matches_on_accepted_at"
    t.index ["carrier_id"], name: "index_matches_on_carrier_id"
    t.index ["load_id", "carrier_id"], name: "index_matches_on_load_id_and_carrier_id", unique: true
    t.index ["load_id"], name: "index_matches_on_load_id"
    t.index ["match_score"], name: "index_matches_on_match_score"
    t.index ["matched_at"], name: "index_matches_on_matched_at"
    t.index ["status"], name: "index_matches_on_status"
  end

  create_table "routes", force: :cascade do |t|
    t.bigint "match_id", null: false
    t.decimal "origin_latitude", precision: 10, scale: 6, null: false
    t.decimal "origin_longitude", precision: 10, scale: 6, null: false
    t.decimal "destination_latitude", precision: 10, scale: 6, null: false
    t.decimal "destination_longitude", precision: 10, scale: 6, null: false
    t.decimal "distance_miles", precision: 8, scale: 2
    t.integer "estimated_duration"
    t.text "route_geometry"
    t.text "waypoints"
    t.text "route_instructions"
    t.string "traffic_conditions"
    t.decimal "toll_cost", precision: 8, scale: 2
    t.decimal "fuel_cost", precision: 8, scale: 2
    t.decimal "total_cost", precision: 10, scale: 2
    t.string "optimization_type", default: "fastest"
    t.boolean "avoid_highways", default: false
    t.boolean "avoid_tolls", default: false
    t.text "vehicle_restrictions"
    t.datetime "calculated_at"
    t.datetime "expires_at"
    t.boolean "is_optimized", default: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["calculated_at"], name: "index_routes_on_calculated_at"
    t.index ["destination_latitude", "destination_longitude"], name: "index_routes_on_destination_latitude_and_destination_longitude"
    t.index ["expires_at"], name: "index_routes_on_expires_at"
    t.index ["match_id"], name: "index_routes_on_match_id"
    t.index ["optimization_type"], name: "index_routes_on_optimization_type"
    t.index ["origin_latitude", "origin_longitude"], name: "index_routes_on_origin_latitude_and_origin_longitude"
  end

  create_table "shipments", force: :cascade do |t|
    t.bigint "load_id", null: false
    t.bigint "carrier_id", null: false
    t.bigint "match_id", null: false
    t.string "status", default: "pending_pickup", null: false
    t.date "scheduled_pickup_date", null: false
    t.date "scheduled_delivery_date", null: false
    t.date "actual_pickup_date"
    t.date "actual_delivery_date"
    t.boolean "delivered_on_time", default: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["carrier_id"], name: "index_shipments_on_carrier_id"
    t.index ["delivered_on_time"], name: "index_shipments_on_delivered_on_time"
    t.index ["load_id"], name: "index_shipments_on_load_id"
    t.index ["match_id"], name: "index_shipments_on_match_id"
    t.index ["scheduled_delivery_date"], name: "index_shipments_on_scheduled_delivery_date"
    t.index ["scheduled_pickup_date"], name: "index_shipments_on_scheduled_pickup_date"
    t.index ["status"], name: "index_shipments_on_status"
  end

  create_table "shippers", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "company_name", null: false
    t.text "company_description"
    t.string "industry"
    t.string "address_line1"
    t.string "address_line2"
    t.string "city"
    t.string "state"
    t.string "postal_code"
    t.string "country", default: "US"
    t.decimal "latitude", precision: 10, scale: 6
    t.decimal "longitude", precision: 10, scale: 6
    t.string "phone"
    t.string "website"
    t.string "tax_id"
    t.string "dot_number"
    t.decimal "credit_limit", precision: 10, scale: 2, default: "0.0"
    t.integer "payment_terms", default: 30
    t.text "preferred_carriers"
    t.integer "shipping_volume_monthly", default: 0
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["company_name"], name: "index_shippers_on_company_name"
    t.index ["dot_number"], name: "index_shippers_on_dot_number", unique: true
    t.index ["industry"], name: "index_shippers_on_industry"
    t.index ["latitude", "longitude"], name: "index_shippers_on_latitude_and_longitude"
    t.index ["tax_id"], name: "index_shippers_on_tax_id", unique: true
    t.index ["user_id"], name: "index_shippers_on_user_id"
  end

  create_table "tracking_events", force: :cascade do |t|
    t.bigint "shipment_id", null: false
    t.string "event_type", null: false
    t.string "status", null: false
    t.string "location"
    t.decimal "latitude", precision: 10, scale: 6
    t.decimal "longitude", precision: 10, scale: 6
    t.text "description"
    t.text "notes"
    t.datetime "occurred_at", null: false
    t.string "reported_by"
    t.string "source", default: "manual"
    t.boolean "is_milestone", default: false
    t.decimal "temperature", precision: 5, scale: 2
    t.decimal "humidity", precision: 5, scale: 2
    t.bigint "vehicle_id"
    t.bigint "driver_id"
    t.string "external_id"
    t.text "metadata"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["driver_id"], name: "index_tracking_events_on_driver_id"
    t.index ["event_type"], name: "index_tracking_events_on_event_type"
    t.index ["is_milestone"], name: "index_tracking_events_on_is_milestone"
    t.index ["latitude", "longitude"], name: "index_tracking_events_on_latitude_and_longitude"
    t.index ["occurred_at"], name: "index_tracking_events_on_occurred_at"
    t.index ["shipment_id", "occurred_at"], name: "index_tracking_events_on_shipment_id_and_occurred_at"
    t.index ["shipment_id"], name: "index_tracking_events_on_shipment_id"
    t.index ["source"], name: "index_tracking_events_on_source"
    t.index ["status"], name: "index_tracking_events_on_status"
    t.index ["vehicle_id"], name: "index_tracking_events_on_vehicle_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "first_name", null: false
    t.string "last_name", null: false
    t.string "phone"
    t.string "user_type", null: false
    t.string "status", default: "active", null: false
    t.string "confirmation_token"
    t.datetime "confirmed_at"
    t.datetime "confirmation_sent_at"
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.integer "sign_in_count", default: 0, null: false
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.string "current_sign_in_ip"
    t.string "last_sign_in_ip"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "subscription_tier", default: "standard", null: false
    t.index ["confirmation_token"], name: "index_users_on_confirmation_token", unique: true
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["status"], name: "index_users_on_status"
    t.index ["subscription_tier"], name: "index_users_on_subscription_tier"
    t.index ["user_type"], name: "index_users_on_user_type"
  end

  create_table "vehicles", force: :cascade do |t|
    t.bigint "carrier_id", null: false
    t.bigint "driver_id"
    t.string "vehicle_number", null: false
    t.string "vin", null: false
    t.string "make", null: false
    t.string "model", null: false
    t.integer "year", null: false
    t.string "equipment_type", null: false
    t.decimal "capacity_weight", precision: 8, scale: 2
    t.decimal "capacity_volume", precision: 8, scale: 2
    t.decimal "length", precision: 6, scale: 2
    t.decimal "width", precision: 6, scale: 2
    t.decimal "height", precision: 6, scale: 2
    t.string "fuel_type", default: "diesel"
    t.decimal "mpg", precision: 4, scale: 2
    t.string "status", default: "active", null: false
    t.decimal "current_location_lat", precision: 10, scale: 6
    t.decimal "current_location_lng", precision: 10, scale: 6
    t.datetime "last_location_update"
    t.date "maintenance_due_date"
    t.date "inspection_due_date"
    t.date "registration_expiry"
    t.date "insurance_expiry"
    t.boolean "is_temperature_controlled", default: false
    t.boolean "is_hazmat_certified", default: false
    t.boolean "is_team_capable", default: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["carrier_id", "vehicle_number"], name: "index_vehicles_on_carrier_id_and_vehicle_number", unique: true
    t.index ["carrier_id"], name: "index_vehicles_on_carrier_id"
    t.index ["current_location_lat", "current_location_lng"], name: "idx_on_current_location_lat_current_location_lng_b3fbcf9829"
    t.index ["driver_id"], name: "index_vehicles_on_driver_id"
    t.index ["equipment_type"], name: "index_vehicles_on_equipment_type"
    t.index ["inspection_due_date"], name: "index_vehicles_on_inspection_due_date"
    t.index ["is_hazmat_certified"], name: "index_vehicles_on_is_hazmat_certified"
    t.index ["is_temperature_controlled"], name: "index_vehicles_on_is_temperature_controlled"
    t.index ["maintenance_due_date"], name: "index_vehicles_on_maintenance_due_date"
    t.index ["status"], name: "index_vehicles_on_status"
    t.index ["vin"], name: "index_vehicles_on_vin", unique: true
  end

  add_foreign_key "cargo_details", "loads"
  add_foreign_key "carriers", "users"
  add_foreign_key "drivers", "carriers"
  add_foreign_key "drivers", "users"
  add_foreign_key "drivers", "vehicles"
  add_foreign_key "load_requirements", "loads"
  add_foreign_key "loads", "shippers"
  add_foreign_key "matches", "carriers"
  add_foreign_key "matches", "loads"
  add_foreign_key "routes", "matches"
  add_foreign_key "shipments", "carriers"
  add_foreign_key "shipments", "loads"
  add_foreign_key "shipments", "matches"
  add_foreign_key "shippers", "users"
  add_foreign_key "tracking_events", "drivers"
  add_foreign_key "tracking_events", "shipments"
  add_foreign_key "tracking_events", "vehicles"
  add_foreign_key "vehicles", "carriers"
end
