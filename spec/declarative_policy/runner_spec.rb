# frozen_string_literal: true

require 'rspec-parameterized'

# NB: This spec relies heavily on the fact that calling unstubbed methods on doubles
# will cause examples to fail. Only steps we anticipate being called have
# `pass?` defined for them. All other steps are expected not to be called.
RSpec.describe DeclarativePolicy::Runner do
  it 'short-circuits if there are no enabling steps' do
    prevent_1 = double('Step', score: 1, enable?: false)
    prevent_2 = double('Step', score: 1, enable?: false)
    prevent_3 = double('Step', score: 1, enable?: false)

    runner = make_runner(prevent_1, prevent_2, prevent_3)

    expect(runner).not_to be_pass
  end

  it 'only runs the cheapest prevent step, if it succeeds' do
    prevent_1 = double('Step 1', score: 0.5, enable?: false, action: :prevent, pass?: true)
    prevent_2 = double('Step 2', score: 2, enable?: false)
    prevent_3 = double('Step 3', score: 3, enable?: false)
    enable = double('Step 4', score: 1, enable?: true)

    runner = make_runner(enable, prevent_1, prevent_2, prevent_3)

    expect(runner).not_to be_pass
  end

  it 'runs all prevent steps, if none succeed' do
    prevent_1 = double('Step 1', score: 0.5, enable?: false, action: :prevent, pass?: false)
    prevent_2 = double('Step 2', score: 2, enable?: false, action: :prevent, pass?: false)
    prevent_3 = double('Step 3', score: 3, enable?: false, action: :prevent, pass?: false)
    enable = double('Step 4', score: 1, enable?: true, action: :enable, pass?: true)

    runner = make_runner(enable, prevent_1, prevent_2, prevent_3)

    expect(runner).to be_pass
  end

  it 'runs all enabling steps if none succeed' do
    step_1 = double('Step', score: 1, enable?: true, action: :enable, pass?: false)
    step_2 = double('Step', score: 1, enable?: true, action: :enable, pass?: false)
    step_3 = double('Step', score: 1, enable?: true, action: :enable, pass?: false)

    runner = make_runner(step_1, step_2, step_3)

    expect(runner).not_to be_pass
  end

  it 'skips expensive prevent steps if no cheaper enable succeeds' do
    enable_1 = double('Step', score: 1, enable?: true, action: :enable, pass?: false)
    enable_2 = double('Step', score: 1, enable?: true, action: :enable, pass?: false)
    enable_3 = double('Step', score: 1, enable?: true, action: :enable, pass?: false)
    prevent = double('Step', score: 2, enable?: false)

    runner = make_runner(prevent, enable_1, enable_2, enable_3)

    expect(runner).not_to be_pass
  end

  it 'skips more expensive enabling steps if one succeeds' do
    enable_1 = double('Step', score: 3, enable?: true)
    enable_2 = double('Step', score: 2, enable?: true, action: :enable, pass?: true)
    enable_3 = double('Step', score: 1, enable?: true, action: :enable, pass?: false)

    runner = make_runner(enable_1, enable_2, enable_3)

    expect(runner).to be_pass
  end

  it 'picks up steps that become cheaper during execution' do
    variable_cost = 3

    step_1 = double('Step', enable?: true, action: :enable)
    step_2 = double('Step', enable?: true, action: :enable, score: 2)
    step_3 = double('Step', enable?: true, action: :enable, score: 1)

    allow(step_1).to receive(:score) { variable_cost }

    expect(step_3).to receive(:pass?) do
      variable_cost = 0
      false
    end
    expect(step_1).to receive(:pass?).and_return(true)

    runner = make_runner(step_1, step_2, step_3)

    expect(runner).to be_pass
  end

  describe '#dependencies' do
    let(:policy) do
      Class.new(DeclarativePolicy::Base) do
        condition(:hot, score: 1) { @subject > 30 }
        condition(:cold, score: 2) { @subject < 15 }
        condition(:works_in_office, score: 3) { @user&.works_in_office? }

        rule { ~hot & ~cold }.enable :enjoy_weather
        rule { ~cold }.enable :wear_shorts
        rule { works_in_office }.prevent :wear_shorts
        # tests nested runners
        rule { can?(:wear_shorts) }.enable :wear_tshirt

        # Tests doubly-nested runners
        rule { can?(:enjoy_weather) & can?(:wear_tshirt) }.enable :bonza
      end
    end

    it 'tracks dependencies, cached or fresh' do
      p = policy.new(nil, 20)

      expect(p).to be_allowed(:enjoy_weather)
      expect(p).to be_allowed(:wear_shorts)
      expect(p).to be_allowed(:wear_tshirt)
      expect(p).to be_allowed(:bonza)

      expect(p.runner(:enjoy_weather).dependencies).to contain_exactly(/hot/, /cold/)
      expect(p.runner(:wear_shorts).dependencies).to contain_exactly(/cold/, /works_in_office/)
      expect(p.runner(:wear_tshirt).dependencies).to contain_exactly(/cold/, /works_in_office/)
      expect(p.runner(:bonza).dependencies).to contain_exactly(/hot/, /cold/, /works_in_office/)
    end

    it 'only tracks evaluated dependencies' do
      p = policy.new(nil, 31)

      expect(p).not_to be_allowed(:enjoy_weather)

      expect(p.runner(:enjoy_weather).dependencies).to include(/hot/)
      expect(p.runner(:enjoy_weather).dependencies).not_to include(/cold/)
    end
  end

  def make_runner(*steps)
    steps.each do |step|
      allow(step).to receive(:flattened).and_return([step])
    end

    described_class.new(steps)
  end
end
