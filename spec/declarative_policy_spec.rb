# frozen_string_literal: true

RSpec.describe DeclarativePolicy do
  describe '.class_for' do
    context 'when the value is nil' do
      it 'uses the default fallback policy' do
        expect(described_class.class_for(nil)).to eq(DeclarativePolicy::NilPolicy)
      end

      context 'when nil_policy has been configured' do
        let(:custom_nil_policy) { Class.new(DeclarativePolicy::Base) }

        before do
          policy = custom_nil_policy

          described_class.configure do
            nil_policy policy
          end
        end

        it 'uses the custom class' do
          expect(described_class.class_for(nil)).to eq(custom_nil_policy)
        end
      end
    end

    context 'when the value is a symbol' do
      it 'uses the configured class' do
        expect(described_class.class_for(:global)).to eq(GlobalPolicy)
      end

      it 'raises an error if no policy was configured' do
        expect { described_class.class_for(:custom) }.to raise_error('No custom policy configured')
      end

      context 'when a policy has been configured' do
        let(:custom_policy) { Class.new(DeclarativePolicy::Base) }
        let(:my_global_policy) { Class.new(DeclarativePolicy::Base) }

        before do
          custom = custom_policy
          global = my_global_policy

          described_class.configure do
            named_policy :custom, custom
            named_policy :global, global
          end
        end

        it 'returns the configured policy' do
          expect(described_class.class_for(:global)).to eq(my_global_policy)
          expect(described_class.class_for(:custom)).to eq(custom_policy)
        end
      end
    end

    context 'when the policy class is present' do
      before do
        stub_const('Foo', Class.new)
        stub_const('FooPolicy', Class.new(DeclarativePolicy::Base))
      end

      it 'uses declarative_policy_class' do
        instance = Foo.new

        expect(described_class.class_for(instance)).to eq(FooPolicy)
      end
    end

    context 'when there is no policy for the class, but there is one for a superclass' do
      before do
        foo = Class.new
        stub_const('Foo', foo)
        stub_const('Bar', Class.new(foo))
        stub_const('FooPolicy', Class.new(DeclarativePolicy::Base))
      end

      it 'uses declarative_policy_class' do
        instance = Bar.new

        expect(described_class.class_for(instance)).to eq(FooPolicy)
      end
    end

    it 'raises error if not found' do
      instance = Object.new

      expect { described_class.class_for(instance) }.to raise_error('no policy for Object')
    end

    context 'when found policy class does not inherit base' do
      before do
        stub_const('Foo', Class.new)
        stub_const('FooPolicy', Class.new)
      end

      it 'raises error if inferred class does not inherit Base' do
        instance = Foo.new

        expect { described_class.class_for(instance) }.to raise_error('no policy for Foo')
      end
    end
  end
end
