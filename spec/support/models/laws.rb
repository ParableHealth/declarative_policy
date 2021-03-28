# frozen_string_literal: true

class Laws
  attr_reader :max_blood_alcohol, :minimum_age

  def initialize(max_blood_alcohol:, minimum_age:)
    @max_blood_alcohol = max_blood_alcohol
    @minimum_age = minimum_age
  end
end
