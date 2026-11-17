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

ActiveRecord::Schema[8.1].define(version: 2026_11_17_194227) do
  create_table "app_settings", force: :cascade do |t|
    t.string "source_url"
    t.text "welcome_text"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "players", force: :cascade do |t|
    t.string "name", null: false
    t.string "normalized_name", null: false
    t.string "token", null: false
    t.datetime "blocked_at"
    t.integer "current_streak", default: 0, null: false
    t.integer "best_streak", default: 0, null: false
    t.date "last_streak_on"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "score", default: 0, null: false
    t.index ["normalized_name"], name: "index_players_on_normalized_name", unique: true
    t.index ["token"], name: "index_players_on_token", unique: true
    t.check_constraint "best_streak >= current_streak", name: "players_best_streak_at_least_current"
    t.check_constraint "current_streak >= 0", name: "players_current_streak_not_negative"
    t.check_constraint "length(name) BETWEEN 3 AND 20", name: "players_name_length"
    t.check_constraint "name = trim(name)", name: "players_name_trimmed"
  end

  create_table "score_types", force: :cascade do |t|
    t.string "name", null: false
    t.integer "points", default: 0, null: false
    t.decimal "multiplier", precision: 8, scale: 2, default: "1.0", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_score_types_on_name", unique: true
  end

  create_table "sessions", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "ip_address"
    t.string "user_agent"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email_address", null: false
    t.string "password_digest", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "role", default: "editor", null: false
    t.boolean "active", default: true, null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
  end

  add_foreign_key "sessions", "users"
end
