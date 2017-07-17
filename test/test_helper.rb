require 'rubygems'

require 'rails'
require 'active_record'

require 'rails/test_help'

require File.dirname(__FILE__) + '/../lib/activemodel-caution'

# I can't get the railtie working in testing...
ActiveModel::Caution::Railtie.insert

ActiveRecord::Base.establish_connection(adapter: 'sqlite3', database: ':memory:')

ActiveRecord::Schema.define(version: 0) do
  create_table 'pets', force: true do |t|
    t.string   'name'
    t.string   'category'
    t.date     'birthdate'
    t.text     'description'
    t.string   'status'
    t.datetime 'created_at'
    t.datetime 'updated_at'
  end
end

ActiveSupport.test_order = :random if ActiveSupport.respond_to?(:test_order=)
