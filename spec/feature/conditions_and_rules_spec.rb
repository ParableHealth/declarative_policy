# frozen_string_literal: true

RSpec.describe 'conditions and rules' do
  include_context 'with vehicle model'

  def policy
    user = model[:User].new(name, age, license, blood_alcohol, [])
    owner = model[:User].new(:owner, 32, nil, nil, trusted_users)
    laws = model[:Laws].new(0.01, 18)
    reg = model[:Registration].new(model[:Country].new(laws))
    car = model[:Vehicle].new(owner, reg)

    DeclarativePolicy.policy_for(user, car, cache: {})
  end

  describe 'can?' do
    using RSpec::Parameterized::TableSyntax

    where(:name, :age, :trusted_users, :license, :blood_alcohol, :can, :cannot) do
      valid_licence = Struct.new(:valid?).new(true)

      # full permissions
      :owner  | 18 | []        | valid_licence | 0.0   | [:drive_vehicle, :sell_vehicle] | []
      # drive only
      :driver | 18 | [:driver] | valid_licence | 0.0   | [:drive_vehicle] | [:sell_vehicle]
      :driver | 18 | [:driver] | valid_licence | 0.001 | [:drive_vehicle] | [:sell_vehicle]
      # sell-only
      :owner | 17 | [:driver] | valid_licence | 0.0   | [:sell_vehicle] | [:drive_vehicle]
      :owner | 18 | [:driver] | valid_licence | 0.2   | [:sell_vehicle] | [:drive_vehicle]
      :owner | 18 | [:driver] | nil           | 0.0   | [:sell_vehicle] | [:drive_vehicle]
      # no permissions
      :driver | 17 | [:driver] | valid_licence | 0.0   | [] | [:drive_vehicle, :sell_vehicle]
      :driver | 18 | []        | valid_licence | 0.0   | [] | [:drive_vehicle, :sell_vehicle]
      :driver | 18 | [:driver] | valid_licence | 0.2   | [] | [:drive_vehicle, :sell_vehicle]
      :driver | 18 | [:driver] | nil           | 0.0   | [] | [:drive_vehicle, :sell_vehicle]
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
