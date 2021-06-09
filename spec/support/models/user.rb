# frozen_string_literal: true

class User
  attr_reader :name, :age, :blood_alcohol
  attr_accessor :driving_license

  def initialize(name:, age: 30, driving_license: nil, blood_alcohol: 0.0, trusted: [], citizenships: [])
    @name = name
    @age = age
    @driving_license = driving_license
    @blood_alcohol = blood_alcohol
    @trusted = trusted
    @citizenships = citizenships
  end

  def trusts?(user)
    user && @trusted.include?(user.name)
  end

  def id
    return @name if @citizenships.empty?

    @citizenships.map { |c| "#{c.code}:#{c.number}" }.join(";")
  end

  def citizen_of?(*country_codes)
    country_codes.any? { |c| @citizenships.map(&:code).include?(c) }
  end

  alias_method :to_reference, :name
end
