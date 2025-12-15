#!/usr/bin/env ruby
# bin/run_tests.rb

# Add lib to load path
$LOAD_PATH.unshift File.expand_path('../lib', __dir__)

puts "Running Test Harness..."
puts "=" * 40

# Run the harness specs
require_relative '../spec/harness'

# If we get here without exit, tests passed (Minitest handles exit code)
