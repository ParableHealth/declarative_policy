# frozen_string_literal: true

class Registration
  attr_reader :number, :country

  def initialize(country:, number: nil)
    @number = number
    @country = country
  end
end
