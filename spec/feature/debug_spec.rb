# frozen_string_literal: true

RSpec.describe 'debugging' do
  include_context 'with vehicle policy'

  def policy
    user = User.new(name: :driver, driving_license: License.valid, blood_alcohol: 0.005)
    reg = Registration.new(country: country)
    car = Vehicle.new(owner: owner, registration: reg)

    DeclarativePolicy.policy_for(user, car, cache: {})
  end

  describe '#debug' do
    let(:owner) { User.new(name: :owner, trusted: [:driver]) }

    context 'when the policy succeeds' do
      let(:country) { Country.moderate }

      it 'shows the executed conditions' do
        out = []
        policy.debug(:drive_vehicle, out)

        expect(out).to match [
          start_with("- [0] enable when owns"),
          start_with("+ [3] enable when has_access_to"),
          start_with("- [4] prevent when intoxicated"),
          start_with("- [14] prevent when ~old_enough_to_drive"),
          start_with("- [14] prevent when ~has_driving_license")
        ]
      end
    end

    context 'when the policy is never enabled' do
      let(:country) { Country.moderate }
      let(:owner) { User.new(name: :owner, trusted: []) }

      it 'shows the executed conditions' do
        out = []
        policy.debug(:drive_vehicle, out)

        expect(out).to match [
          start_with("- [0] enable when owns"),
          start_with("- [3] enable when has_access_to"),
          start_with("  [4] prevent when intoxicated"),
          start_with("  [14] prevent when ~old_enough_to_drive"),
          start_with("  [14] prevent when ~has_driving_license")
        ]
      end
    end

    context 'when the policy fails due to prevention' do
      let(:country) { Country.strict }

      it 'shows the executed conditions' do
        out = []
        policy.debug(:drive_vehicle, out)

        expect(out).to match [
          start_with("- [0] enable when owns"),
          start_with("+ [3] enable when has_access_to"),
          start_with("+ [4] prevent when intoxicated"),
          start_with("  [14] prevent when ~old_enough_to_drive"),
          start_with("  [14] prevent when ~has_driving_license")
        ]
      end
    end
  end
end
