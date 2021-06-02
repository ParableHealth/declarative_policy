# frozen_string_literal: true

RSpec.describe DeclarativePolicy::Rule do
  let(:ctx) { double(:Policy) }
  let(:pass_value) { true }
  let(:cache_state) { true }
  let(:score) { 17 }
  let(:delegated_policies) { {} }

  let(:manifest_condition) do
    double(:ManifestCondition, pass?: pass_value, cached?: cache_state, score: score)
  end

  before do
    allow(ctx).to receive(:condition).with(:foo).and_return(manifest_condition)
    allow(ctx).to receive(:delegated_policies).and_return(delegated_policies)
  end

  describe 'combinators' do
    let(:x) { DeclarativePolicy::Rule::Condition.new(:x) }
    let(:y) { DeclarativePolicy::Rule::Condition.new(:y) }

    describe '#or' do
      it 'builds an Or node' do
        expect(x.or(y).repr).to eq 'any?(x, y)'
        expect((x | y).repr).to eq 'any?(x, y)'
      end
    end

    describe '#and' do
      it 'builds an And node' do
        expect(x.and(y).repr).to eq 'all?(x, y)'
        expect((x & y).repr).to eq 'all?(x, y)'
      end
    end

    describe '#negate' do
      it 'builds a Not node' do
        expect(x.negate.repr).to eq '~x'
        expect((~y).repr).to eq '~y'
      end
    end
  end

  describe DeclarativePolicy::Rule::Condition do
    subject { described_class.new(:foo) }

    describe '#pass?' do
      it 'delegates to the underlying condition' do
        expect(subject.pass?(ctx)).to eq pass_value
      end
    end

    describe '#cached_pass?' do
      context 'when cached' do
        it 'calls pass?' do
          expect(manifest_condition).to receive(:pass?)

          expect(subject.cached_pass?(ctx)).to eq pass_value
        end
      end

      context 'when not cached' do
        let(:cache_state) { false }

        it 'does not call pass' do
          expect(manifest_condition).not_to receive(:pass?)

          expect(subject.cached_pass?(ctx)).to be_nil
        end
      end
    end

    describe '#score' do
      # see ManifestCondition for scoring rules when cached.
      it 'delegates to the underlying condition' do
        expect(subject.score(ctx)).to eq 17
      end
    end

    describe '#simplify' do
      it 'cannot be simplfied' do
        expect(subject.simplify).to be subject
      end
    end

    describe '#inspect' do
      it 'is represented by the condition name' do
        expect(subject.repr).to eq 'foo'
      end
    end
  end

  describe DeclarativePolicy::Rule::Not do
    let(:underlying) { DeclarativePolicy::Rule::Condition.new(:foo) }

    subject { described_class.new(underlying) }

    describe '#pass?' do
      it 'is the inverse of the underlying rule' do
        expect(subject.pass?(ctx)).to eq !underlying.pass?(ctx)
      end
    end

    describe '#cached_pass?' do
      context 'when cached' do
        it 'calls pass?' do
          expect(manifest_condition).to receive(:pass?)

          expect(subject.cached_pass?(ctx)).to eq !pass_value
        end
      end

      context 'when not cached' do
        let(:cache_state) { false }

        it 'does not call pass' do
          expect(manifest_condition).not_to receive(:pass?)

          expect(subject.cached_pass?(ctx)).to be_nil
        end
      end
    end

    describe '#score' do
      it 'delegates to the underlying condition' do
        expect(subject.score(ctx)).to eq 17
      end
    end

    describe '#simplify' do
      it 'cannot be simplfied' do
        expect(subject.simplify.repr).to eq subject.repr
      end

      context 'when there is double-negation' do
        let(:underlying) { described_class.new(DeclarativePolicy::Rule::Condition.new(:foo)) }

        it 'discards the negation' do
          expect(subject.simplify.repr).to eq 'foo'
        end
      end

      context "with DeMorgan's Law" do
        let(:a) { DeclarativePolicy::Rule::Condition.new(:a) }
        let(:b) { DeclarativePolicy::Rule::Condition.new(:b) }

        context 'with !(a && b)' do
          let(:underlying) { a & b }

          it 'simplifies to (!a || !b)' do
            expect(subject.simplify.repr).to eq((~a | ~b).repr)
          end
        end

        context 'with !(a || b)' do
          let(:underlying) { a | b }

          it 'simplifies to (!a && !b)' do
            expect(subject.simplify.repr).to eq((~a & ~b).repr)
          end
        end
      end
    end

    describe '#inspect' do
      it 'is represented by the condition name prefixed with ~' do
        expect(subject.repr).to eq '~foo'
      end
    end
  end

  describe DeclarativePolicy::Rule::DelegatedCondition do
    subject { described_class.new(:wibble, :foo) }

    describe '#pass?' do
      context 'when the delegate does not exist' do
        it 'is false' do
          expect(subject.pass?(ctx)).to be false
        end
      end

      context 'when the delegate does exist' do
        let(:delegated_policies) { { wibble: ctx } }

        it 'is whatever the delegated condition returns' do
          expect(subject.pass?(ctx)).to eq pass_value
        end
      end
    end

    describe '#cached_pass?' do
      context 'when the delegate does not exist' do
        it 'is false' do
          expect(subject.cached_pass?(ctx)).to be false
        end
      end

      context 'when the delegate does exist' do
        let(:delegated_policies) { { wibble: ctx } }

        context 'when cached' do
          it 'calls pass?' do
            expect(manifest_condition).to receive(:pass?)

            expect(subject.cached_pass?(ctx)).to eq pass_value
          end
        end

        context 'when not cached' do
          let(:cache_state) { false }

          it 'does not call pass' do
            expect(manifest_condition).not_to receive(:pass?)

            expect(subject.cached_pass?(ctx)).to be_nil
          end
        end
      end
    end

    describe '#score' do
      context 'when the delegate does not exist' do
        it 'is zero' do
          expect(subject.score(ctx)).to eq 0
        end
      end

      context 'when the delegate does exist' do
        let(:delegated_policies) { { wibble: ctx } }

        it 'delegates to the underlying condition' do
          expect(subject.score(ctx)).to eq 17
        end
      end
    end

    describe '#simplify' do
      it 'cannot be simplfied' do
        expect(subject.simplify.repr).to eq subject.repr
      end
    end

    describe '#inspect' do
      it 'is represented by the delegate name followed by the condition name' do
        expect(subject.repr).to eq 'wibble.foo'
      end
    end
  end

  describe DeclarativePolicy::Rule::Ability do
    let(:runner) { double(:Runner, score: 13, cached?: cache_state, pass?: pass_value) }

    before do
      allow(ctx).to receive(:runner).with(:do_foo).and_return(runner)
    end

    subject { described_class.new(:do_foo) }

    describe '#pass?' do
      it 'is equivalent to calling Policy#allowed?(ability)' do
        expect(ctx).to receive(:allowed?).with(:do_foo).and_return(pass_value)

        expect(subject.pass?(ctx)).to eq pass_value
      end
    end

    describe '#cached_pass?' do
      context 'when cached' do
        it 'calls pass?' do
          expect(runner).to receive(:pass?)

          expect(subject.cached_pass?(ctx)).to eq pass_value
        end
      end

      context 'when not cached' do
        let(:cache_state) { false }

        it 'does not call pass' do
          expect(runner).not_to receive(:pass?)

          expect(subject.cached_pass?(ctx)).to be_nil
        end
      end
    end

    describe '#score' do
      it 'delegates to the runner' do
        expect(subject.score(ctx)).to eq 13
      end
    end

    describe '#simplify' do
      it 'cannot be simplfied' do
        expect(subject.simplify.repr).to eq subject.repr
      end
    end

    describe '#inspect' do
      it 'is represented by can and the ability name' do
        expect(subject.repr).to eq 'can?(:do_foo)'
      end
    end
  end

  describe DeclarativePolicy::Rule::And do
    let(:rules) do
      [
        DeclarativePolicy::Rule::Condition.new(:foo),
        DeclarativePolicy::Rule::Condition.new(:bar),
        DeclarativePolicy::Rule::Condition.new(:baz)
      ]
    end

    let(:bar) { { pass: true, cached: true, score: 7 } }
    let(:baz) { { pass: true, cached: true, score: 8 } }

    def cond(values)
      double(:ManifestCondition, pass?: values[:pass], cached?: values[:cached], score: values[:score])
    end

    before do
      allow(ctx).to receive(:condition).with(:bar) { cond(bar) }
      allow(ctx).to receive(:condition).with(:baz) { cond(baz) }
    end

    subject { described_class.new(rules) }

    describe '#pass?' do
      it 'is equivalent to rules.all? { _1.pass? }' do
        expect(subject.pass?(ctx)).to eq true
      end

      context 'when any rule does not pass' do
        it 'does not pass' do
          bar[:pass] = false

          expect(subject.pass?(ctx)).to eq false
        end
      end
    end

    describe '#cached_pass?' do
      context 'when all rules are cached' do
        it 'calls pass? on each rule' do
          expect(subject.cached_pass?(ctx)).to eq true
        end
      end

      context 'when not fully cached' do
        before do
          baz[:cached] = false
        end

        it 'does not call pass' do
          expect(subject.rules.last).not_to receive(:pass?)

          expect(subject.cached_pass?(ctx)).to be_nil
        end
      end

      context 'when not fully cached, but known to be false' do
        before do
          baz[:cached] = false
          bar[:pass] = false
        end

        it 'is false' do
          expect(subject.cached_pass?(ctx)).to eq false
        end
      end
    end

    describe '#score' do
      context 'when fully cached' do
        it 'is zero' do
          expect(subject.score(ctx)).to eq 0
        end
      end

      context 'when not fully cached' do
        before do
          baz[:cached] = false
        end

        it 'is the sum of the score of the rules' do
          expect(subject.score(ctx)).to eq(17 + 7 + 8)
        end
      end

      context 'when not fully cached, but known to be false' do
        before do
          baz[:cached] = false
          bar[:pass] = false
        end

        it 'is zero' do
          expect(subject.score(ctx)).to eq 0
        end
      end
    end

    describe '#simplify' do
      it 'cannot be simplfied' do
        expect(subject.simplify.repr).to eq subject.repr
      end

      context 'when any of the rules are themselves AND nodes, or simplify to AND nodes' do
        let(:new_rules) do
          [
            DeclarativePolicy::Rule::Condition.new(:x),
            DeclarativePolicy::Rule::Condition.new(:y),
            DeclarativePolicy::Rule::Condition.new(:w),
            DeclarativePolicy::Rule::Condition.new(:z)
          ]
        end

        before do
          x, y, w, z = new_rules
          and_node = described_class.new([x, y])
          demorgan_and = DeclarativePolicy::Rule::Not.new(DeclarativePolicy::Rule::Or.new([w, z]))

          rules << and_node
          rules << demorgan_and
        end

        it 'flattens out any nested rules' do
          expect(subject.simplify.repr).to eq 'all?(foo, bar, baz, x, y, ~w, ~z)'
        end
      end
    end

    describe '#inspect' do
      it 'is represented by all? and the rules' do
        expect(subject.repr).to eq 'all?(foo, bar, baz)'
      end
    end
  end

  describe DeclarativePolicy::Rule::Or do
    let(:rules) do
      [
        DeclarativePolicy::Rule::Condition.new(:foo),
        DeclarativePolicy::Rule::Condition.new(:bar),
        DeclarativePolicy::Rule::Condition.new(:baz)
      ]
    end

    let(:bar) { { pass: false, cached: true, score: 7 } }
    let(:baz) { { pass: false, cached: true, score: 8 } }

    def cond(values)
      double(:ManifestCondition, pass?: values[:pass], cached?: values[:cached], score: values[:score])
    end

    before do
      allow(ctx).to receive(:condition).with(:bar) { cond(bar) }
      allow(ctx).to receive(:condition).with(:baz) { cond(baz) }
    end

    subject { described_class.new(rules) }

    describe '#pass?' do
      it 'is equivalent to rules.any? { _1.pass? }' do
        expect(subject.pass?(ctx)).to eq true
      end

      context 'when no rule passes' do
        let(:pass_value) { false }

        it 'does not pass' do
          expect(subject.pass?(ctx)).to eq false
        end
      end
    end

    describe '#cached_pass?' do
      context 'when all rules are cached' do
        it 'is true' do
          expect(subject.cached_pass?(ctx)).to eq true
        end
      end

      context 'when any false rule is not cached' do
        before do
          baz[:cached] = false
        end

        it 'is true' do
          expect(subject.cached_pass?(ctx)).to eq true
        end
      end

      context 'when the true rule is not cached' do
        let(:cache_state) { false }

        it 'is unknown' do
          expect(subject.cached_pass?(ctx)).to be_nil
        end
      end
    end

    describe '#score' do
      context 'when fully cached' do
        it 'is zero' do
          expect(subject.score(ctx)).to eq 0
        end
      end

      context 'when the true condition is not cached' do
        let(:cache_state) { false }

        it 'is the sum of the score of the rules' do
          expect(subject.score(ctx)).to eq(17 + 7 + 8)
        end
      end

      context 'when a false condition is not cached' do
        before do
          bar[:cached] = false
        end

        it 'is zero' do
          expect(subject.score(ctx)).to eq 0
        end
      end
    end

    describe '#simplify' do
      it 'cannot be simplfied' do
        expect(subject.simplify.repr).to eq subject.repr
      end

      context 'when any of the rules are themselves OR nodes, or simplify to OR nodes' do
        let(:new_rules) do
          [
            DeclarativePolicy::Rule::Condition.new(:x),
            DeclarativePolicy::Rule::Condition.new(:y),
            DeclarativePolicy::Rule::Condition.new(:w),
            DeclarativePolicy::Rule::Condition.new(:z)
          ]
        end

        before do
          x, y, w, z = new_rules
          or_node = described_class.new([x, y])
          demorgan_or = DeclarativePolicy::Rule::Not.new(DeclarativePolicy::Rule::And.new([w, z]))

          rules << or_node
          rules << demorgan_or
        end

        it 'flattens out any nested rules' do
          expect(subject.simplify.repr).to eq 'any?(foo, bar, baz, x, y, ~w, ~z)'
        end
      end
    end

    describe '#inspect' do
      it 'is represented by all? and the rules' do
        expect(subject.repr).to eq 'any?(foo, bar, baz)'
      end
    end
  end
end
