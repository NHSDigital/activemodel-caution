module ActiveModel
  module Caution
    def self.included(base)
      ActiveSupport::Deprecation.warn(<<-MESSAGE.squish)
        Including `ActiveModel::Caution` is deprecated!

        In future, please use `ActiveModel::Cautions` instead.
      MESSAGE
      base.include(Cautions)
    end
  end
end