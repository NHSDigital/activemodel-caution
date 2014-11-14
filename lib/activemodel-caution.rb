require 'active_model/caution'
# Custom extension, to keep the basic /caution a mirror of active_model/validation:
require 'active_model/cautions/safety_decision'

ActiveRecord::Base.send :include, ActiveModel::Caution
ActiveRecord::Base.send :include, ActiveModel::Caution::Callbacks
ActiveRecord::Base.send :include, ActiveModel::Caution::SafetyDecision
