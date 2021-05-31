# frozen_string_literal: true

RSpec.describe DeclarativePolicy::Base do
  context 'when a condition is declared in two classes' do
    let(:rules_a) do
      Class.new(described_class) do
        condition(:suitable) { subject == :a }

        rule { suitable }.enable(:ok)
      end
    end

    let(:rules_b) do
      Class.new(described_class) do
        condition(:suitable) { subject == :b }

        rule { suitable }.enable(:ok)
      end
    end

    let(:cache) { {} }

    def policy(rules, object)
      rules.new(nil, object, cache: cache)
    end

    it 'is does not overwrite the cache entries of conditions with the same name' do
      expect(policy(rules_a, :foo)).not_to be_allowed(:ok)
      expect(policy(rules_b, :foo)).not_to be_allowed(:ok)

      expect(policy(rules_a, :a)).to be_allowed(:ok)
      expect(policy(rules_b, :a)).not_to be_allowed(:ok)

      expect(policy(rules_a, :b)).not_to be_allowed(:ok)
      expect(policy(rules_b, :b)).to be_allowed(:ok)
    end

    it 'writes separate cache entries for each condition' do
      expect do
        policy(rules_a, :foo).allowed?(:ok)
        policy(rules_b, :foo).allowed?(:ok)
      end.to change(cache, :size).by(2)
    end
  end
end
