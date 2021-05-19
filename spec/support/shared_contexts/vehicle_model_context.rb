# frozen_string_literal: true

RSpec.shared_context 'with vehicle policy' do
  let(:vehicle_policy) { ReadmePolicy }

  # functionally identical to the ReadmePolicy, but the conditions are combined differently
  let(:nested_vehicle_policy) do
    Class.new(DeclarativePolicy::Base) do
      condition(:old_enough_to_drive) { @user.age >= laws.minimum_age }
      condition(:has_driving_license) { @user.driving_license&.valid? }
      condition(:owns, score: 0) { @subject.owner.name == @user.name }
      condition(:has_access_to, score: 3) { @subject.owner.trusts?(@user) }
      condition(:intoxicated, score: 5) { @user.blood_alcohol > laws.max_blood_alcohol }
      condition(:banned, score: 4) { @subject.registration.country.current_driving_conviction?(@user) }

      # The rule as one big nested condition
      rule do
        (owns | has_access_to) & old_enough_to_drive & ~(intoxicated | banned) & has_driving_license
      end.enable :drive_vehicle

      rule { owns }.enable :sell_vehicle

      def laws
        @subject.registration.country.driving_laws
      end
    end
  end

  before do
    stub_const('VehiclePolicy', vehicle_policy)
  end
end
