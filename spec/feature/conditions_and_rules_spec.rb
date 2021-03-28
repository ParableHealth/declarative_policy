# frozen_string_literal: true

RSpec.describe 'conditions and rules' do
  include_context 'with vehicle policy'

  def policy
    user = User.new(name: name, age: age, driving_license: license, blood_alcohol: blood_alcohol)
    owner = User.new(name: :owner, trusted: trusted_users)
    reg = Registration.new(country: Country.moderate)
    car = Vehicle.new(owner: owner, registration: reg)

    DeclarativePolicy.policy_for(user, car, cache: {})
  end

  describe 'can?' do
    using RSpec::Parameterized::TableSyntax

    where(:name, :age, :trusted_users, :license, :blood_alcohol, :can, :cannot) do
      # full permissions
      :owner  | 18 | []        | License.valid | 0.0   | [:drive_vehicle, :sell_vehicle] | []
      # drive only
      :driver | 18 | [:driver] | License.valid | 0.0   | [:drive_vehicle] | [:sell_vehicle]
      :driver | 18 | [:driver] | License.valid | 0.001 | [:drive_vehicle] | [:sell_vehicle]
      # sell-only
      :owner | 17 | [:driver] | License.valid   | 0.0   | [:sell_vehicle] | [:drive_vehicle]
      :owner | 18 | [:driver] | License.valid   | 0.2   | [:sell_vehicle] | [:drive_vehicle]
      :owner | 18 | [:driver] | License.expired | 0.0   | [:sell_vehicle] | [:drive_vehicle]
      :owner | 18 | [:driver] | nil             | 0.0   | [:sell_vehicle] | [:drive_vehicle]
      # no permissions
      :driver | 17 | [:driver] | License.valid   | 0.0   | [] | [:drive_vehicle, :sell_vehicle]
      :driver | 18 | []        | License.valid   | 0.0   | [] | [:drive_vehicle, :sell_vehicle]
      :driver | 18 | [:driver] | License.valid   | 0.2   | [] | [:drive_vehicle, :sell_vehicle]
      :driver | 18 | [:driver] | License.expired | 0.2   | [] | [:drive_vehicle, :sell_vehicle]
      :driver | 18 | [:driver] | nil             | 0.0   | [] | [:drive_vehicle, :sell_vehicle]
    end

    with_them do
      specify do
        expect(policy).to be_allowed(*can)
      end

      specify do
        expect(policy).to be_disallowed(*cannot)
      end
    end
  end
end
