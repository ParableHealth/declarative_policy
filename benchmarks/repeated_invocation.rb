#!/usr/bin/env ruby -w
# frozen_string_literal: true

require 'declarative_policy'
require 'benchmark'

Dir["./spec/support/policies/*.rb"].sort.each { |f| require f }
Dir["./spec/support/models/*.rb"].sort.each { |f| require f }

TIMES = 1_000_000
LABEL = 'allowed?(driver, :drive_vehicle, car)'

DeclarativePolicy.configure! do
  named_policy :global, GlobalPolicy

  name_transformation do |name|
    'ReadmePolicy' if name == 'Vehicle'
  end
end

Benchmark.bm(LABEL.length) do |b|
  cache = {}
  valid_license = License.valid
  country = Country.moderate
  registration = Registration.new(number: 'xyz123', country: country)
  driver = User.new(name: 'The driver', driving_license: valid_license)
  owner = User.new(name: 'The Owner', trusted: [driver.name])
  car = Vehicle.new(owner: owner, registration: registration)

  raise 'Expected to drive' unless DeclarativePolicy.policy_for(driver, car).allowed?(:drive_vehicle)

  b.report LABEL do
    TIMES.times do
      DeclarativePolicy.policy_for(driver, car, cache: cache).allowed?(:drive_vehicle)
    end
  end
end
