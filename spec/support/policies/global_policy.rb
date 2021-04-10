# frozen_string_literal: true

class GlobalPolicy < DeclarativePolicy::Base
  rule { anonymous }.prevent :drive_car

  rule { ~anonymous }.enable :say_hello
end
