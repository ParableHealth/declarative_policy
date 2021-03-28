# frozen_string_literal: true

class Vehicle
  attr_reader :owner, :registration

  def initialize(owner:, registration:)
    @owner = owner
    @registration = registration
  end
end
