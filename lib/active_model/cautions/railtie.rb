module ActiveModel
  module Caution
    class Railtie < ::Rails::Railtie
      ActiveSupport.on_load(:active_record) do
        ActiveModel::Caution.register!
      end
    end
  end
end
