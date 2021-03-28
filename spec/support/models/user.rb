# frozen_string_literal: true

class User
  attr_reader :name, :age, :driving_license, :blood_alcohol

  def initialize(name:, age: 30, driving_license: nil, blood_alcohol: 0.0, trusted: [])
    @name = name
    @age = age
    @driving_license = driving_license
    @blood_alcohol = blood_alcohol
    @trusted = trusted
  end

  def trusts?(user)
    user.present? && @trusted.include?(user.name)
  end

  alias_method :to_reference, :name
end
