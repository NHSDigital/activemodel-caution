module ActiveModel
  module Caution
    def self.register!
      require 'active_model/caution'
      # Custom extension, to keep the basic /caution a mirror of active_model/validation:
      require 'active_model/cautions/safety_decision'

      ActiveRecord::Base.send :include, ActiveModel::Caution
      ActiveRecord::Base.send :include, ActiveModel::Caution::Callbacks
      ActiveRecord::Base.send :include, ActiveModel::Caution::SafetyDecision
    end
  end
end

if defined?(Rails)
  # Place nicely with Rails
  require 'active_model/cautions/railtie'
else
  # Attempt to just work...
  ActiveModel::Caution.register!
end
