# frozen_string_literal: true

class Country
  attr_reader :name, :driving_laws

  def initialize(name:, driving_laws:)
    @name = name
    @driving_laws = driving_laws
  end

  def self.strict
    new(name: 'Strictopia', driving_laws: Laws.new(max_blood_alcohol: 0.001, minimum_age: 21))
  end

  def self.moderate
    new(name: 'Moderia', driving_laws: Laws.new(max_blood_alcohol: 0.01, minimum_age: 18))
  end
end
