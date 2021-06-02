# frozen_string_literal: true

# Also includes tests for some combining methods on `Rule`.
# This defines the specification for what can appear in a `rule { ... }` block.
RSpec.describe DeclarativePolicy::RuleDsl do
  def temperature(value)
    policy.new(nil, value)
  end

  let(:low_range) { (-200..-1) }
  let(:mid_range) { (0..100) }
  let(:high_range) { (101..200) }

  let(:base_policy) do
    Class.new(DeclarativePolicy::Base) do
      condition(:zero) { value.zero? }
      condition(:even) { value.even? }
      condition(:odd) { value.odd? }
      condition(:high) { value > 100 }
      condition(:low) { value < 0 }
      condition(:always) { true }
      condition(:never) { false }

      rule { ~high & ~low }.enable :liquid_water

      def value
        @subject
      end
    end
  end

  it 'cannot refer to the subject directly' do
    expect do
      Class.new(base_policy) do
        rule { @subject.positive? }.enable :positive
      end
    end.to raise_error(NoMethodError)
  end

  it 'cannot refer to other policy methods' do
    policy = Class.new(base_policy) do
      rule { value == 1 }.enable :one
    end.new(nil, 1)

    expect { policy.allowed?(:one) }.to raise_error(NoMethodError)
    expect { policy.allowed?(:liquid_water) }.not_to raise_error
  end

  describe 'use of bare words' do
    let(:policy) do
      Class.new(base_policy) do
        rule { high }.enable :steam
      end
    end

    it 'refers to conditions by name' do
      expect(low_range.map { temperature(_1) }).to all(be_disallowed(:steam))
      expect(mid_range.map { temperature(_1) }).to all(be_disallowed(:steam))
      expect(high_range.map { temperature(_1) }).to all(be_allowed(:steam))
    end
  end

  describe 'delegate' do
    let(:succ) { Struct.new(:value) }

    let(:policy) do
      Class.new(base_policy) do
        delegate(:succ) { Succ.new(@subject.succ) }

        rule { delegate(:succ, :even) }.enable :odd
      end
    end

    # this is needed to break infinite recursion
    # policies are eager in their delegations!
    let(:succ_policy) do
      Class.new(base_policy) do
        def value
          @subject.value
        end
      end
    end

    before do
      DeclarativePolicy.configure do
        name_transformation { |name| 'SuccPolicy' if name == 'Succ' }
      end
      stub_const('SuccPolicy', succ_policy)
      stub_const('Succ', succ)
    end

    it 'refers to a condition on a delegate by name' do
      expect(temperature(9)).to be_allowed(:odd)
      expect(temperature(10)).not_to be_allowed(:odd)
    end
  end

  describe 'cond' do
    let(:policy) do
      Class.new(base_policy) do
        rule { cond(:high) }.enable :steam
      end
    end

    it 'refers to conditions by name' do
      expect(low_range.map { temperature(_1) }).to all(be_disallowed(:steam))
      expect(mid_range.map { temperature(_1) }).to all(be_disallowed(:steam))
      expect(high_range.map { temperature(_1) }).to all(be_allowed(:steam))
    end
  end

  describe 'use of |' do
    let(:policy) do
      Class.new(base_policy) do
        rule { high | low }.enable :unsurvivable
      end
    end

    it 'requires one condition' do
      expect(low_range.map { temperature(_1) }).to all(be_allowed(:unsurvivable))
      expect(mid_range.map { temperature(_1) }).to all(be_disallowed(:unsurvivable))
      expect(high_range.map { temperature(_1) }).to all(be_allowed(:unsurvivable))
    end
  end

  describe 'any?' do
    let(:policy) do
      Class.new(base_policy) do
        rule { any?(high, low) }.enable :unsurvivable
      end
    end

    it 'requires one condition' do
      expect(low_range.map { temperature(_1) }).to all(be_allowed(:unsurvivable))
      expect(mid_range.map { temperature(_1) }).to all(be_disallowed(:unsurvivable))
      expect(high_range.map { temperature(_1) }).to all(be_allowed(:unsurvivable))
    end
  end

  describe 'none?' do
    let(:policy) do
      Class.new(base_policy) do
        rule { none?(high, low) }.enable :survivable
      end
    end

    it 'requires neither condition' do
      expect(low_range.map { temperature(_1) }).to all(be_disallowed(:survivable))
      expect(mid_range.map { temperature(_1) }).to all(be_allowed(:survivable))
      expect(high_range.map { temperature(_1) }).to all(be_disallowed(:survivable))
    end
  end

  describe 'all?' do
    let(:policy) do
      Class.new(base_policy) do
        rule { all?(~high, ~low) }.enable :liquid_water
        rule { all?(~high, ~low, even) }.enable :even_liquid
        rule { all?(~high, ~low, even, never) }.enable :quodlibet
      end
    end

    it 'requires both conditions' do
      expect(low_range.map { temperature(_1) }).to all(be_disallowed(:liquid_water, :even_liquid))
      expect(high_range.map { temperature(_1) }).to all(be_disallowed(:liquid_water, :even_liquid))

      expect(temperature(1)).to be_allowed(:liquid_water)
      expect(temperature(1)).not_to be_allowed(:even_liquid)
      expect(temperature(2)).to be_allowed(:liquid_water)
      expect(temperature(2)).to be_allowed(:even_liquid)
      expect(temperature(100)).to be_allowed(:liquid_water)
      expect(temperature(100)).to be_allowed(:even_liquid)

      (low_range.to_a + mid_range.to_a + high_range.to_a).each do |i|
        expect(temperature(i)).not_to be_allowed(:quodlibet)
      end
    end
  end

  describe 'use of &' do
    let(:policy) do
      Class.new(base_policy) do
        rule { ~high & ~low }.enable :liquid_water
        rule { ~high & ~low & even }.enable :even_liquid
        rule { ~high & ~low & even & never }.enable :quodlibet
      end
    end

    it 'requires both conditions' do
      expect(low_range.map { temperature(_1) }).to all(be_disallowed(:liquid_water, :even_liquid))
      expect(high_range.map { temperature(_1) }).to all(be_disallowed(:liquid_water, :even_liquid))

      expect(temperature(1)).to be_allowed(:liquid_water)
      expect(temperature(1)).not_to be_allowed(:even_liquid)
      expect(temperature(2)).to be_allowed(:liquid_water)
      expect(temperature(2)).to be_allowed(:even_liquid)
      expect(temperature(100)).to be_allowed(:liquid_water)
      expect(temperature(100)).to be_allowed(:even_liquid)

      (low_range.to_a + mid_range.to_a + high_range.to_a).each do |i|
        expect(temperature(i)).not_to be_allowed(:quodlibet)
      end
    end
  end

  describe '~' do
    let(:policy) do
      Class.new(base_policy) do
        rule { ~even }.enable :uneven
        rule { ~can?(:uneven) }.enable :ununeven
      end
    end

    it 'is the inverse of the condition' do
      (-10..10).each do |i|
        if i.even?
          expect(temperature(i)).to be_allowed(:ununeven)
          expect(temperature(i)).not_to be_allowed(:uneven)
        else
          expect(temperature(i)).not_to be_allowed(:ununeven)
          expect(temperature(i)).to be_allowed(:uneven)
        end
      end
    end
  end

  describe 'can?' do
    let(:policy) do
      Class.new(base_policy) do
        rule { ~high & ~low }.enable :liquid_water
        rule { can?(:liquid_water) }.enable :other_ability
      end
    end

    it 'infers the state from other rules' do
      (low_range.to_a + mid_range.to_a + high_range.to_a).each do |i|
        t = temperature(i)

        matcher = t.allowed?(:liquid_water) ? be_allowed(:other_ability) : be_disallowed(:other_ability)
        expect(t).to match matcher
      end
    end
  end
end
