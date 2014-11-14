module ActiveModel

  module Caution
    class InclusionCautioner < EachCautioner
      def check_validity!
         raise ArgumentError, "An object with the method include? is required must be supplied as the " <<
                              ":in option of the configuration hash" unless options[:in].respond_to?(:include?)
      end

      if (1..2).respond_to?(:cover?)
        def caution_each(record, attribute, value)
          included = if options[:in].is_a?(Range)
            options[:in].cover?(value)
          else
            options[:in].include?(value)
          end

          unless included
            record.warnings.add(attribute, :inclusion, options.except(:in).merge!(:value => value))
          end
        end
      else
        def caution_each(record, attribute, value)
          unless options[:in].include?(value)
            record.warnings.add(attribute, :inclusion, options.except(:in).merge!(:value => value))
          end
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
