# frozen_string_literal: true

RSpec.describe 'conditions and rules' do
  let(:model) do
    {
      user_class: Struct.new(:name, :age, :driving_license, :blood_alcohol, :trusted) do
        def trusts?(user)
          trusted.include?(user.name)
        end
      end,
      laws_class: Struct.new(:max_blood_alcohol, :minimum_age),
      vehicle_class: Struct.new(:owner, :registration)
    }
  end

  let(:vehicle_policy) do
    # See README.md
    Class.new(DeclarativePolicy::Base) do
      condition(:old_enough_to_drive) { @user.age >= laws.minimum_age }
      condition(:has_driving_license) { @user.driving_license&.valid? }
      condition(:owns, score: 0) { @subject.owner.name == @user.name }
      condition(:has_access_to, score: 3) { @subject.owner.trusts?(@user) }
      condition(:intoxicated, score: 5) { @user.blood_alcohol >= laws.max_blood_alcohol }

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

  def laws
    model[:laws_class].new(0.01, 18)
  end

  def valid_licence
    double(:License, valid?: true)
  end

  def policy
    user = model[:user_class].new(name, age, license, blood_alcohol, [])
    owner = model[:user_class].new(:owner, 32, nil, nil, trusted_users)
    reg = double(:Reg, country: double(:Country, driving_laws: laws))
    car = model[:vehicle_class].new(owner, reg)

    DeclarativePolicy.policy_for(user, car, cache: {})
  end

  before do
    stub_const('Vehicle', model[:vehicle_class])
    stub_const('VehiclePolicy', vehicle_policy)
  end

  describe 'can?' do
    let(:name) { :driver }
    let(:age) { 18 }
    let(:trusted_users) { [:driver] }
    let(:license) { valid_licence }
    let(:blood_alcohol) { 0.0 }

    context 'when the user is trusted, old enough, has a valid license, and is not drunk' do
      it 'is allowed to drive' do
        expect(policy.can?(:drive_vehicle)).to be true
      end

      it 'is forbidden to sell' do
        expect(policy.can?(:sell_vehicle)).to be false
      end
    end

    context 'when the user owns the vehicle, old enough, has a valid license, and is not drunk' do
      let(:name) { :owner }

      it 'is allowed to drive' do
        expect(policy.can?(:drive_vehicle)).to be true
      end

      it 'is allowed to sell' do
        expect(policy.can?(:sell_vehicle)).to be true
      end

      context 'when the owner is drunk' do
        let(:blood_alcohol) { 0.2 }

        it 'is still allowed to sell' do
          expect(policy.can?(:sell_vehicle)).to be true
        end
      end
    end

    context 'when the user is not trusted' do
      let(:trusted_users) { [] }

      it 'is forbidden to drive' do
        expect(policy.can?(:drive_vehicle)).to be false
      end

      it 'is forbidden to sell' do
        expect(policy.can?(:sell_vehicle)).to be false
      end
    end

    context 'when the user is too young to drive' do
      let(:age) { 17 }

      it 'is forbidden to drive' do
        expect(policy.can?(:drive_vehicle)).to be false
      end

      it 'is forbidden to sell' do
        expect(policy.can?(:sell_vehicle)).to be false
      end
    end

    context 'when the user does not have a valid license' do
      let(:license) { double(valid?: false) }

      it 'is forbidden to drive' do
        expect(policy.can?(:drive_vehicle)).to be false
      end

      it 'is forbidden to sell' do
        expect(policy.can?(:sell_vehicle)).to be false
      end
    end

    context 'when the user is intoxicated' do
      let(:blood_alcohol) { 0.2 }

      it 'is forbidden to drive' do
        expect(policy.can?(:drive_vehicle)).to be false
      end

      it 'is forbidden to sell' do
        expect(policy.can?(:sell_vehicle)).to be false
      end
    end
  end
end
