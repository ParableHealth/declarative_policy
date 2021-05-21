# frozen_string_literal: true

RSpec.describe 'conditions and rules' do
  include_context 'with vehicle policy'

  let(:user) { User.new(name: name, age: age, driving_license: license, blood_alcohol: blood_alcohol) }
  let(:car) do
    owner = User.new(name: :owner, trusted: trusted_users)
    country = Country.moderate
    allow(country).to receive(:current_driving_conviction?).with(user).and_return(banned)
    reg = Registration.new(country: country)
    Vehicle.new(owner: owner, registration: reg)
  end

  let(:cache) { {} }

  def policy
    vehicle_policy.new(user, car, cache: cache)
  end

  shared_context 'with vehicle policy scenarios' do
    where(:name, :age, :trusted_users, :license, :banned, :blood_alcohol, :can, :cannot) do
      [
        # full permissions
        [:owner, 18, [], License.valid, false, 0.0, [:drive_vehicle, :sell_vehicle], []],
        # drive only
        [:driver, 18, [:driver], License.valid, false, 0.0, [:drive_vehicle], [:sell_vehicle]],
        [:driver, 18, [:driver], License.valid, false, 0.001, [:drive_vehicle], [:sell_vehicle]],
        # sell-only
        [:owner, 17, [:driver], License.valid, false, 0.0, [:sell_vehicle], [:drive_vehicle]],
        [:owner, 18, [:driver], License.valid, false, 0.2, [:sell_vehicle], [:drive_vehicle]],
        [:owner, 18, [:driver], License.expired, false, 0.0, [:sell_vehicle], [:drive_vehicle]],
        [:owner, 18, [:driver], nil, false, 0.0, [:sell_vehicle], [:drive_vehicle]],
        [:owner, 18, [:driver], nil, true, 0.0, [:sell_vehicle], [:drive_vehicle]],
        [:owner, 18, [:driver], nil, true, 0.001, [:sell_vehicle], [:drive_vehicle]],
        # no permissions
        [:driver, 17, [:driver], License.valid, false, 0.0, [], [:drive_vehicle, :sell_vehicle]],
        [:driver, 18, [], License.valid, false, 0.0, [], [:drive_vehicle, :sell_vehicle]],
        [:driver, 18, [:driver], License.valid, false, 0.2, [], [:drive_vehicle, :sell_vehicle]],
        [:driver, 18, [:driver], License.expired, false, 0.2, [], [:drive_vehicle, :sell_vehicle]],
        [:driver, 18, [:driver], nil, false, 0.0, [], [:drive_vehicle, :sell_vehicle]],
        [:driver, 18, [:driver], License.valid, true, 0.0, [], [:drive_vehicle, :sell_vehicle]]
      ]
    end
  end

  describe 'the Vehicle policy' do
    include_context 'with vehicle policy scenarios'

    with_them do
      specify do
        expect(policy).to be_allowed(*can)
      end

      specify do
        expect(policy).to be_disallowed(*cannot)
      end

      context 'with a nested policy definition' do
        let(:policy) { nested_vehicle_policy.new(user, car, cache: cache) }

        it 'is functionally identical to the declarative API' do
          expect(policy).to be_allowed(*can)
          expect(policy).to be_disallowed(*cannot)
        end
      end

      context 'with a forgetful cache' do
        before do
          allow(cache).to receive(:[]).and_return(nil)
        end

        it 'has no effect on the correctness of the results' do
          expect(policy).to be_allowed(*can)
          expect(policy).to be_disallowed(*cannot)
        end
      end
    end
  end

  describe 'ability inference' do
    let(:policy_definition) { Class.new(vehicle_policy) }
    let(:policy) { policy_definition.new(user, car, cache: {}) }

    before do
      policy_definition.rule { default }.enable(:take_bus)

      policy_definition.rule { can?(:sell_vehicle) }.enable(:trade_in_vehicle)
      policy_definition.rule { can?(:drive_vehicle) }.prevent(:take_bus)
    end

    describe 'allowed?' do
      include_context 'with vehicle policy scenarios'

      with_them do
        specify do
          if policy.allowed?(:sell_vehicle)
            expect(policy).to be_allowed(:trade_in_vehicle)
          else
            expect(policy).to be_disallowed(:trade_in_vehicle)
          end
        end

        specify do
          if policy.allowed?(:drive_vehicle)
            expect(policy).to be_disallowed(:take_bus)
          else
            expect(policy).to be_allowed(:take_bus)
          end
        end
      end
    end
  end
end
