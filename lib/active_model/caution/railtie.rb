module ActiveModel
  module Caution
    class Railtie < ::Rails::Railtie
      initializer "activemodel-caution.register_with_active_record" do
        ActiveSupport.on_load(:active_record) do
          ActiveModel::Caution::Railtie.insert
        end
      end

      def self.insert
        ActiveRecord::Base.include(ActiveModel::Cautions)
        ActiveRecord::Base.include(ActiveModel::Cautions::Callbacks)
        ActiveRecord::Base.include(ActiveModel::Cautions::SafetyDecision)
      end
    end
  end
end
