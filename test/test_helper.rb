$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)

require 'simplecov'
require 'coveralls'

SimpleCov.formatters = [
  SimpleCov::Formatter::HTMLFormatter,
  Coveralls::SimpleCov::Formatter
]

SimpleCov.start do
  add_filter '/test/'
  minimum_coverage(95)
end

require 'dependable'
require 'byebug'
require 'minitest/autorun'
require 'minitest/reporters'

Minitest::Reporters.use! Minitest::Reporters::SpecReporter.new

def s(name, service_block = nil, parent: Object)
  create_service(name: name, parent: parent, &service_block)

  yield

  cleanup_service(name: name)
end

def create_service(name: nil, parent: Object, &block)
  Class.new(parent, &block).tap do |service|
    Object.const_set(name, service) if name
  end
end

def cleanup_service(name: nil)
  Object.send(:remove_const, name) if name
end

def assert_array_contents_equal(actual, expected, message = nil)
  actual_set   = Set.new actual
  expected_set = Set.new expected

  assert_equal actual_set, expected_set, message
end
