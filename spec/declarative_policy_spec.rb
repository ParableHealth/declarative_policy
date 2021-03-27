# frozen_string_literal: true

RSpec.describe DeclarativePolicy do
  describe '.class_for' do
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
