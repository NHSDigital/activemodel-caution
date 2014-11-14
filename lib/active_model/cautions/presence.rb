module ActiveModel
  module Caution
    class PresenceCautioner < EachCautioner
      def caution(record)
        record.warnings.add_on_blank(attributes, options)
      end
    end

    module HelperMethods
      def cautions_presence_of(*attr_names)
        cautions_with PresenceCautioner, _merge_attributes(attr_names)
      end
    end
  end
end
