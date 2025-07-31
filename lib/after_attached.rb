# frozen_string_literal: true

require "active_support"
require "active_support/concern"

require_relative "after_attached/version"
require_relative "after_attached/attachment_callbacks"
require_relative "after_attached/railtie" if defined?(Rails::Railtie)

module AfterAttached
  class Error < StandardError; end
end
