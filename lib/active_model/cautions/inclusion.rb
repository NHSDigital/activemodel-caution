require "active_model/validations/clusivity"

module ActiveModel
  module Cautions
    class InclusionCautioner < EachCautioner # :nodoc:
      include ActiveModel::Validations::Clusivity

      def caution_each(record, attribute, value)
        unless include?(record, value)
          record.warnings.add(attribute, :inclusion, options.except(:in, :within).merge!(value: value))
        end
      end
    end

    module HelperMethods
      def cautions_inclusion_of(*attr_names)
        cautions_with InclusionCautioner, _merge_attributes(attr_names)
      end
    end
  end
end
