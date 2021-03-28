# frozen_string_literal: true

class License
  def initialize(expiry:)
    @expiry = expiry
  end

  def valid?
    Time.current <= @expiry
  end

  def self.valid
    new(expiry: 10.years.from_now)
  end

  def self.expired
    new(expiry: 1.day.ago)
  end
end
