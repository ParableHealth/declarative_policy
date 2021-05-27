# frozen_string_literal: true

RSpec.shared_context 'with vehicle policy' do
  let(:vehicle_policy) do
    # See README.md
    Class.new(DeclarativePolicy::Base) do
      condition(:old_enough_to_drive) { @user.age >= laws.minimum_age }
      condition(:has_driving_license) { @user.driving_license&.valid? }
      condition(:owns, score: 0) { @subject.owner.name == @user.name }
      condition(:has_access_to, score: 3) { @subject.owner.trusts?(@user) }
      condition(:intoxicated, score: 5) { @user.blood_alcohol > laws.max_blood_alcohol }

      # conclusions we can draw:
      rule { owns }.enable :drive_vehicle
      rule { has_access_to }.enable :drive_vehicle
      rule { ~old_enough_to_drive }.prevent :drive_vehicle
      rule { intoxicated }.prevent :drive_vehicle
      rule { ~has_driving_license }.prevent :drive_vehicle
      rule { owns }.enable :sell_vehicle

      # we can use methods to abstract common logic
      def laws
        @subject.registration.country.driving_laws
      end
    end
  end

  before do
    stub_const('VehiclePolicy', vehicle_policy)
  end
end
