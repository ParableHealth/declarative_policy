# frozen_string_literal: true

# Tests caching promises, as well as the code presented in doc/caching.md
RSpec.describe 'caching' do
  let(:policy) { CountryPolicy.new(user, country, cache: cache) }
  let(:cache) { {} }

  let(:user) { User.new(name: 'Hans', citizenships: [double(code: :de, number: 1234)]) }

  let(:european_union) { %i[de fr it] }
  let(:visas) { double(:Visas) }
  let(:current_visa) { nil }

  before do
    stub_const('Unions::EU', european_union)
    allow(visas).to receive(:find_by).once.with(applicant: user).and_return(current_visa)
    allow(country.visa_waivers).to receive(:any?).once.and_call_original
  end

  context 'when the country is a member of the EU' do
    let(:country) { Country.new(name: 'France', active_visas: visas) }

    it 'is OK to visit, work and settle in another EU country' do
      expect(policy).to be_allowed(:enter_country, :work, :settle)
    end

    it 'does not confer voting rights' do
      expect(policy).not_to be_allowed(:vote)
    end

    it 'tests citizenship at most once' do
      # This tests that we prefer to test EU citizenship before specific
      # citizenship, because EU citizenship is split into a user and a subject
      # scope, and is thus has a lower score than `full_rights`
      expect(user).to receive(:citizen_of?).once.and_call_original

      policy.allowed?(:settle)
    end

    context 'when many users are visiting a country' do
      let(:users) do
        %w[Hans Frieda Hilda Mattias].each_with_index.map do |name, i|
          citizenship = double(code: :de, number: i)
          User.new(name: name, citizenships: [citizenship])
        end
      end

      it 'only checks EU membership once' do
        allow(cache).to receive(:[]=).with(String, anything).and_call_original
        expect(cache).to receive(:[]=).once.with(/eu_member/, anything).and_call_original
        expect(cache).to receive(:[]=).with(/eu_citizen/, anything).exactly(4).times.and_call_original

        ok = users.all? do |user|
          CountryPolicy.new(user, country, cache: cache).allowed?(:enter_country)
        end

        expect(ok).to be true
      end
    end

    context 'when one user is visiting many countries' do
      let(:countries) do
        %w[France Italia].map { |name| Country.new(name: name, active_visas: visas) }
      end

      it 'only checks EU citizenship once' do
        allow(cache).to receive(:[]=).with(String, anything).and_call_original
        expect(cache).to receive(:[]=).once.with(/eu_citizen/, anything).and_call_original
        expect(cache).to receive(:[]=).twice.with(/eu_member/, anything).and_call_original

        ok = countries.all? do |country|
          CountryPolicy.new(user, country, cache: cache).allowed?(:enter_country)
        end

        expect(ok).to be true
      end
    end
  end

  context 'when the user comes from a country with a visa waiver arrangment' do
    let(:country) { Country.new(name: 'NZ', active_visas: visas) }

    before do
      country.visa_waivers << :de
    end

    it 'is OK to visit and attend meetings, and apply for a real visa' do
      expect(policy).to be_allowed(:enter_country, :attend_meetings, :apply_for_visa)
    end

    it 'is not OK to work or settle' do
      expect(policy).not_to be_allowed(:work, :settle)
    end

    context 'when the user has a work visa' do
      let(:current_visa) { double(category: :work) }

      it 'is OK to work, but not settle' do
        expect(policy).to be_allowed(:work)
        expect(policy).not_to be_allowed(:settle)
      end
    end

    context 'when the user is banned' do
      before do
        country.banned_list << user
      end

      it 'is not OK to enter the country' do
        expect(policy).not_to be_allowed(:enter_country)
      end
    end
  end
end
