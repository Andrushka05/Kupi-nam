# encoding: UTF-8
# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 20140301091623) do

  create_table "catalog_shops", force: true do |t|
    t.string   "title"
    t.string   "url"
    t.integer  "shop_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.time     "time_download"
    t.datetime "date_last_download"
  end

  add_index "catalog_shops", ["shop_id"], name: "index_catalog_shops_on_shop_id", using: :btree

  create_table "ext_props", force: true do |t|
    t.string   "title"
    t.string   "value"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "photos", force: true do |t|
    t.string   "url"
    t.integer  "product_id"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "photos", ["product_id"], name: "index_photos_on_product_id", using: :btree

  create_table "prices", force: true do |t|
    t.float    "cost"
    t.integer  "product_id"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "prices", ["product_id"], name: "index_prices_on_product_id", using: :btree

  create_table "products", force: true do |t|
    t.string   "title"
    t.string   "color"
    t.string   "article"
    t.string   "size"
    t.string   "category_path"
    t.text     "description"
    t.string   "state"
    t.string   "main_categories"
    t.string   "article2"
    t.string   "url"
    t.integer  "shop_id"
    t.integer  "catalog_shop_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "client_prices",   limit: 50
  end

  add_index "products", ["catalog_shop_id"], name: "index_products_on_catalog_shop_id", using: :btree
  add_index "products", ["shop_id"], name: "index_products_on_shop_id", using: :btree

  create_table "shops", force: true do |t|
    t.string   "title"
    t.string   "xpath"
    t.string   "url"
    t.string   "host"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

end
