# frozen_string_literal: true

require "bundler/setup"

ENV["RAILS_ENV"] = "test"

require "rails"
require "active_record"
require "active_support/core_ext/string"
require "active_storage/engine"

# Create a minimal Rails app for testing
class TestApplication < Rails::Application
  config.load_defaults Rails::VERSION::STRING.to_f
  config.eager_load = false

  # Skip all the Rails initializers we don't need
  config.active_support.deprecation = :stderr
  config.secret_key_base = "test"

  # Configure ActiveStorage
  config.active_storage.service_configurations = {
    test: {
      service: "Disk",
      root: Rails.root.join("tmp/storage")
    }
  }
  config.active_storage.service = :test

  # Skip database config file
  config.paths.add "config/database", with: "spec/dummy_database.yml"
end

# Initialize Rails application
Rails.application.initialize!

# Now we can require our gem
require "after_attached"

# Run the railtie initializers manually
if defined?(AfterAttached::Railtie)
  AfterAttached::Railtie.initializers.each do |initializer|
    initializer.run(Rails.application)
  end
end

# Then trigger the hooks
ActiveSupport.run_load_hooks(:active_record, ActiveRecord::Base)
ActiveSupport.run_load_hooks(:active_storage_attachment, ActiveStorage::Attachment)

# Set up database
ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")

# Create tables
ActiveRecord::Schema.define do
  create_table :active_storage_blobs do |t|
    t.string   :key,          null: false
    t.string   :filename,     null: false
    t.string   :content_type
    t.text     :metadata
    t.string   :service_name, null: false
    t.bigint   :byte_size,    null: false
    t.string   :checksum,     null: false

    t.datetime :created_at,   null: false

    t.index [ :key ], unique: true
  end

  create_table :active_storage_attachments do |t|
    t.string     :name,     null: false
    t.references :record,   null: false, polymorphic: true, index: false
    t.references :blob,     null: false

    t.datetime :created_at, null: false

    t.index [ :record_type, :record_id, :name, :blob_id ], name: :index_active_storage_attachments_uniqueness,
                                                           unique: true
    t.foreign_key :active_storage_blobs, column: :blob_id
  end

  create_table :active_storage_variant_records do |t|
    t.belongs_to :blob, null: false, index: false
    t.string :variation_digest, null: false

    t.index [ :blob_id, :variation_digest ], name: :index_active_storage_variant_records_uniqueness, unique: true
    t.foreign_key :active_storage_blobs, column: :blob_id
  end

  create_table :documents do |t|
    t.string :name
    t.timestamps
  end
end

# Configure RSpec
RSpec.configure do |config|
  config.disable_monkey_patching!
  config.example_status_persistence_file_path = ".rspec_status"

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.before(:each) do
    %w[active_storage_attachments active_storage_blobs documents].each do |table|
      ActiveRecord::Base.connection.execute("DELETE FROM #{table}")
    end
  end

  config.after(:suite) do
    FileUtils.rm_rf(Rails.root.join("tmp/storage"))
  end
end
