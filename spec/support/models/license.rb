# frozen_string_literal: true

class License
  def initialize(expiry:)
    @expiry = expiry
  end

  def valid?
    Time.now <= @expiry
  end

  def self.valid
    new(expiry: (Time.now + 60 * 60 * 24 * 365 * 10))
  end

  def self.expired
    new(expiry: (Time.now - 60 * 60 * 24))
  end
end
