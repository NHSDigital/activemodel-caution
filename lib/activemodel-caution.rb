require 'active_model/caution'
# Custom extension, to keep the basic /caution a mirror of active_model/validation:
require 'active_model/cautions/safety_decision'

require 'active_model/cautions/railtie' if defined?(Rails)
