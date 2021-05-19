# frozen_string_literal: true

# See README.md
class ReadmePolicy < DeclarativePolicy::Base
  condition(:old_enough_to_drive) { @user.age >= laws.minimum_age }
  condition(:has_driving_license) { @user.driving_license&.valid? }
  condition(:owns, score: 0) { @subject.owner.name == @user.name }
  condition(:has_access_to, score: 3) { @subject.owner.trusts?(@user) }
  condition(:intoxicated, score: 5) { @user.blood_alcohol > laws.max_blood_alcohol }
  condition(:banned, score: 4) { @subject.registration.country.current_driving_conviction?(@user) }

  # conclusions we can draw:
  rule { owns }.enable :drive_vehicle
  rule { has_access_to }.enable :drive_vehicle
  rule { ~old_enough_to_drive }.prevent :drive_vehicle
  rule { intoxicated }.prevent :drive_vehicle
  rule { banned }.prevent :drive_vehicle
  rule { ~has_driving_license }.prevent :drive_vehicle
  rule { owns }.enable :sell_vehicle

  # we can use methods to abstract common logic
  def laws
    @subject.registration.country.driving_laws
  end
end
