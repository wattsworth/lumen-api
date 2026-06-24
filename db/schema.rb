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

ActiveRecord::Schema[8.1].define(version: 2026_06_19_130434) do
  create_table "data_apps", id: :integer, default: nil, force: :cascade do |t|
    t.datetime "created_at", precision: nil, null: false
    t.string "joule_id"
    t.string "name"
    t.integer "nilm_id"
    t.datetime "updated_at", precision: nil, null: false
    t.index ["nilm_id"], name: "index_data_apps_on_nilm_id"
  end

  create_table "data_views", force: :cascade do |t|
    t.datetime "created_at", precision: nil, null: false
    t.string "description"
    t.text "image"
    t.string "name"
    t.text "redux_json"
    t.datetime "updated_at", precision: nil, null: false
    t.integer "user_id"
    t.string "visibility"
  end

  create_table "data_views_nilms", force: :cascade do |t|
    t.integer "data_view_id"
    t.integer "nilm_id"
    t.index ["data_view_id"], name: "index_data_views_nilms_on_data_view_id"
    t.index ["nilm_id"], name: "index_data_views_nilms_on_nilm_id"
  end

  create_table "db_decimations", id: :integer, default: nil, force: :cascade do |t|
    t.datetime "created_at", precision: nil, null: false
    t.string "data_type"
    t.integer "db_stream_id"
    t.integer "end_time", limit: 8
    t.integer "level", limit: 8
    t.integer "start_time", limit: 8
    t.integer "total_rows", limit: 8
    t.integer "total_time", limit: 8
    t.datetime "updated_at", precision: nil, null: false
  end

  create_table "db_elements", id: :integer, default: nil, force: :cascade do |t|
    t.integer "column"
    t.datetime "created_at", precision: nil, null: false
    t.integer "db_stream_id"
    t.float "default_max"
    t.float "default_min"
    t.string "display_type"
    t.string "name"
    t.float "offset"
    t.boolean "plottable"
    t.float "scale_factor"
    t.string "units"
    t.datetime "updated_at", precision: nil, null: false
  end

  create_table "db_folders", id: :integer, default: nil, force: :cascade do |t|
    t.datetime "created_at", precision: nil, null: false
    t.integer "db_id"
    t.string "description"
    t.integer "end_time", limit: 8
    t.boolean "hidden"
    t.integer "joule_id"
    t.datetime "last_update", default: "1970-01-01 00:00:00"
    t.boolean "locked"
    t.string "name"
    t.integer "parent_id"
    t.string "path"
    t.integer "size_on_disk", limit: 8
    t.integer "start_time", limit: 8
    t.datetime "updated_at", precision: nil, null: false
    t.index ["joule_id"], name: "index_db_folders_on_joule_id"
  end

  create_table "db_streams", id: :integer, default: nil, force: :cascade do |t|
    t.boolean "active", default: false
    t.datetime "created_at", precision: nil, null: false
    t.string "data_type"
    t.integer "db_folder_id"
    t.integer "db_id"
    t.boolean "delete_locked"
    t.string "description"
    t.integer "end_time", limit: 8
    t.boolean "hidden"
    t.integer "joule_id"
    t.datetime "last_update", default: "1970-01-01 00:00:00"
    t.boolean "locked"
    t.string "name"
    t.string "name_abbrev"
    t.string "path"
    t.integer "size_on_disk", limit: 8
    t.integer "start_time", limit: 8
    t.integer "total_rows", limit: 8
    t.integer "total_time", limit: 8
    t.datetime "updated_at", precision: nil, null: false
    t.index ["joule_id"], name: "index_db_streams_on_joule_id"
  end

  create_table "dbs", force: :cascade do |t|
    t.boolean "available"
    t.datetime "created_at", precision: nil, null: false
    t.integer "db_folder_id"
    t.integer "max_events_per_plot", default: 200
    t.integer "max_points_per_plot", default: 3600
    t.integer "nilm_id"
    t.integer "size_db", limit: 8
    t.integer "size_other", limit: 8
    t.integer "size_total", limit: 8
    t.datetime "updated_at", precision: nil, null: false
    t.string "url"
    t.string "version"
  end

  create_table "event_streams", id: :integer, default: nil, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "db_folder_id"
    t.integer "db_id"
    t.string "description"
    t.integer "end_time", limit: 8
    t.integer "event_count"
    t.string "event_fields_json"
    t.integer "joule_id"
    t.datetime "last_update", default: "1970-01-01 00:00:00"
    t.string "name"
    t.string "path"
    t.integer "start_time", limit: 8
    t.datetime "updated_at", null: false
    t.index ["db_folder_id"], name: "index_event_streams_on_db_folder_id"
    t.index ["db_id"], name: "index_event_streams_on_db_id"
    t.index ["joule_id"], name: "index_event_streams_on_joule_id"
  end

  create_table "interface_auth_tokens", id: :integer, default: nil, force: :cascade do |t|
    t.datetime "created_at", precision: nil, null: false
    t.integer "data_app_id"
    t.datetime "expiration", precision: nil
    t.datetime "updated_at", precision: nil, null: false
    t.integer "user_id"
    t.string "value"
    t.index ["data_app_id"], name: "index_interface_auth_tokens_on_data_app_id"
    t.index ["user_id"], name: "index_interface_auth_tokens_on_user_id"
  end

  create_table "interface_permissions", force: :cascade do |t|
    t.datetime "created_at", precision: nil, null: false
    t.integer "interface_id"
    t.integer "precedence"
    t.string "role"
    t.datetime "updated_at", precision: nil, null: false
    t.integer "user_group_id"
    t.integer "user_id"
    t.index ["interface_id"], name: "index_interface_permissions_on_interface_id"
  end

  create_table "memberships", force: :cascade do |t|
    t.integer "user_group_id"
    t.integer "user_id"
    t.index ["user_group_id"], name: "index_memberships_on_user_group_id"
    t.index ["user_id"], name: "index_memberships_on_user_id"
  end

  create_table "nilm_auth_keys", force: :cascade do |t|
    t.datetime "created_at", precision: nil, null: false
    t.string "key"
    t.datetime "updated_at", precision: nil, null: false
    t.integer "user_id"
  end

  create_table "nilms", force: :cascade do |t|
    t.datetime "created_at", precision: nil, null: false
    t.string "description"
    t.string "key"
    t.string "name"
    t.string "node_type"
    t.string "node_uuid"
    t.datetime "updated_at", precision: nil, null: false
    t.string "url"
  end

  create_table "permissions", id: :integer, default: nil, force: :cascade do |t|
    t.datetime "created_at", precision: nil, null: false
    t.integer "nilm_id"
    t.string "role"
    t.datetime "updated_at", precision: nil, null: false
    t.integer "user_group_id"
    t.integer "user_id"
  end

  create_table "user_groups", force: :cascade do |t|
    t.datetime "created_at", precision: nil, null: false
    t.string "description"
    t.string "name"
    t.integer "owner_id"
    t.datetime "updated_at", precision: nil, null: false
  end

  create_table "users", id: :integer, default: nil, force: :cascade do |t|
    t.boolean "allow_password_change", default: false, null: false
    t.datetime "confirmation_sent_at", precision: nil
    t.string "confirmation_token"
    t.datetime "confirmed_at", precision: nil
    t.datetime "created_at", precision: nil, null: false
    t.datetime "current_sign_in_at", precision: nil
    t.string "current_sign_in_ip"
    t.string "email"
    t.string "encrypted_password", default: ""
    t.string "first_name"
    t.integer "home_data_view_id"
    t.datetime "invitation_accepted_at", precision: nil
    t.datetime "invitation_created_at", precision: nil
    t.integer "invitation_limit"
    t.datetime "invitation_sent_at", precision: nil
    t.string "invitation_token"
    t.string "invitation_url"
    t.integer "invited_by_id"
    t.string "invited_by_type"
    t.string "last_name"
    t.datetime "last_sign_in_at", precision: nil
    t.string "last_sign_in_ip"
    t.string "provider", default: "email", null: false
    t.datetime "remember_created_at", precision: nil
    t.datetime "reset_password_sent_at", precision: nil
    t.string "reset_password_token"
    t.integer "sign_in_count", default: 0, null: false
    t.text "tokens"
    t.string "uid", default: "", null: false
    t.string "unconfirmed_email"
    t.datetime "updated_at", precision: nil, null: false
    t.index ["confirmation_token"], name: "index_users_on_confirmation_token", unique: true
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["invitation_token"], name: "index_users_on_invitation_token", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["uid", "provider"], name: "index_users_on_uid_and_provider", unique: true
  end
end
