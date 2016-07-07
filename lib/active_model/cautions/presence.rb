module ActiveModel
  module Cautions
    class PresenceCautioner < EachCautioner # :nodoc:
      def caution_each(record, attr_name, value)
        record.warnings.add(attr_name, :blank, options) if value.blank?
      end
    end

    module HelperMethods
      def cautions_presence_of(*attr_names)
        cautions_with PresenceCautioner, _merge_attributes(attr_names)
      end
    end
  end
end
