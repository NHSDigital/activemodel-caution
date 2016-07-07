require 'active_support'
require 'active_support/rails'

require 'active_model/caution/included'
require 'active_model/caution/railtie' if defined?(Rails)
require 'active_model/caution/version'

module ActiveModel
  extend ActiveSupport::Autoload

  autoload :BlockCautioner, 'active_model/cautioner'
  autoload :EachCautioner, 'active_model/cautioner'
  autoload :Cautions
  autoload :Cautioner

  eager_autoload do
    autoload :Warnings
  end
end


ActiveSupport.on_load(:i18n) do
  I18n.load_path << File.dirname(__FILE__) + '/active_model/locale/en.yml'
end
