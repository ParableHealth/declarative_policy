# frozen_string_literal: true

class Country
  attr_reader :name, :driving_laws, :visa_waivers, :active_visas, :country_code, :banned_list

  def initialize(
    name:, driving_laws: nil, code: nil,
    visa_waivers: [], active_visas: [], banned_list: [], convictions: {})
    @name = name
    @driving_laws = driving_laws || Laws.new(max_blood_alcohol: 0.01, minimum_age: 18)
    @visa_waivers = visa_waivers
    @active_visas = active_visas
    @country_code = code || name.downcase[0..1].to_sym
    @banned_list = []
    @convictions = convictions
  end

  def id
    country_code
  end

  def self.strict
    new(name: 'Strictopia', driving_laws: Laws.new(max_blood_alcohol: 0.001, minimum_age: 21))
  end

  def self.moderate
    new(name: 'Moderia', driving_laws: Laws.new(max_blood_alcohol: 0.01, minimum_age: 18))
  end

  def current_driving_conviction?(user)
    @convictions.key?(user)
  end
end
