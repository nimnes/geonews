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
# It's strongly recommended to check this file into your version control system.

ActiveRecord::Schema.define(:version => 20130415092000) do

  create_table "countries", :force => true do |t|
    t.string   "code"
    t.text     "name"
    t.text     "capital"
    t.float    "latitude"
    t.float    "longitude"
    t.datetime "created_at", :null => false
    t.datetime "updated_at", :null => false
  end

  create_table "feed_entries", :force => true do |t|
    t.text     "name"
    t.text     "summary"
    t.text     "url"
    t.datetime "published_at"
    t.text     "guid"
    t.string   "location"
    t.datetime "created_at",   :null => false
    t.datetime "updated_at",   :null => false
    t.string   "tags"
    t.string   "category"
    t.string   "source"
  end

  create_table "feeds", :force => true do |t|
    t.string   "title"
    t.string   "url"
    t.string   "feed_url"
    t.string   "etag"
    t.datetime "last_modified"
    t.datetime "created_at",    :null => false
    t.datetime "updated_at",    :null => false
  end

  create_table "geonames", :force => true do |t|
    t.string   "geonameid"
    t.text     "name"
    t.float    "latitude"
    t.float    "longitude"
    t.string   "fclass"
    t.string   "acode"
    t.integer  "population"
    t.datetime "created_at", :null => false
    t.datetime "updated_at", :null => false
  end

  create_table "learning_corpus", :force => true do |t|
    t.string   "toponym"
    t.text     "context"
    t.text     "referents"
    t.string   "entryid"
    t.datetime "created_at", :null => false
    t.datetime "updated_at", :null => false
  end

  create_table "user_rules", :force => true do |t|
    t.string   "rule"
    t.string   "toponym"
    t.string   "referent"
    t.datetime "created_at", :null => false
    t.datetime "updated_at", :null => false
    t.string   "ruletype"
  end

  create_table "world_cities", :force => true do |t|
    t.string   "geonameid"
    t.text     "name"
    t.float    "latitude"
    t.float    "longitude"
    t.integer  "population"
    t.datetime "created_at", :null => false
    t.datetime "updated_at", :null => false
  end

end
