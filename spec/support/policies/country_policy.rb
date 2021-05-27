# frozen_string_literal: true

class CountryPolicy < DeclarativePolicy::Base
  condition(:citizen) { @user.citizen_of?(country.country_code) }
  condition(:eu_citizen, scope: :user) { @user.citizen_of?(*Unions::EU) }
  condition(:eu_member, scope: :subject) { Unions::EU.include?(country.country_code) }

  condition(:has_visa_waiver)    { country.visa_waivers.any? { |c| @user.citizen_of?(c) } }
  condition(:permanent_resident) { visa_category == :permanent }
  condition(:has_work_visa)      { visa_category == :work }
  condition(:has_current_visa)   { has_visa_waiver? || current_visa.present? }
  condition(:has_business_visa)  { has_visa_waiver? || has_work_visa? || visa_category == :business }

  condition(:full_rights, score: 20) { citizen? || permanent_resident? }
  condition(:banned) { country.banned_list.include?(@user) }

  rule { eu_member & eu_citizen }.enable :freedom_of_movement
  rule { full_rights | can?(:freedom_of_movement) }.enable :settle
  rule { can?(:settle) | has_current_visa }.enable :enter_country
  rule { can?(:settle) | has_business_visa }.enable :attend_meetings
  rule { can?(:settle) | has_work_visa }.enable :work
  rule { citizen }.enable :vote
  rule { ~citizen & ~permanent_resident }.enable :apply_for_visa
  rule { banned }.prevent :enter_country, :apply_for_visa

  def current_visa
    return @current_visa if defined?(@current_visa)

    @current_visa = country.active_visas.find_by(applicant: @user)
  end

  def visa_category
    current_visa&.category
  end

  def country
    @subject
  end
end
