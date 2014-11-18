module ActiveModel
  module Caution
    class Railtie < ::Rails::Railtie
      initializer "activemodel-caution.register_with_active_record" do
        ActiveSupport.on_load(:active_record) do
          ActiveModel::Caution::Railtie.insert
        end
      end
    end
    
    class Railtie
      def self.insert
        ActiveRecord::Base.send :include, ActiveModel::Caution
        ActiveRecord::Base.send :include, ActiveModel::Caution::Callbacks
        ActiveRecord::Base.send :include, ActiveModel::Caution::SafetyDecision
      end
    end
  end
end
