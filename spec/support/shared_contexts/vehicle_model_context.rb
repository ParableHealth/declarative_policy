# frozen_string_literal: true

RSpec.shared_context 'with vehicle policy' do
  let(:vehicle_policy) { ReadmePolicy }

  before do
    stub_const('VehiclePolicy', vehicle_policy)
  end
end
