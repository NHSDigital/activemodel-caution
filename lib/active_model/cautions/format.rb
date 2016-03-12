module ActiveModel
  # == Active Model Format Validator
  module Caution
    class FormatCautioner < EachCautioner
      def caution_each(record, attribute, value)
        if options[:with]
          regexp = option_call(record, :with)
          record_warning(record, attribute, :with, value) if value.to_s !~ regexp
        elsif options[:without]
          regexp = option_call(record, :without)
          record_warning(record, attribute, :without, value) if value.to_s =~ regexp
        end
      end

      def check_validity!
        unless options.include?(:with) ^ options.include?(:without)  # ^ == xor, or "exclusive or"
          raise ArgumentError, "Either :with or :without must be supplied (but not both)"
        end

        check_options_validity(options, :with)
        check_options_validity(options, :without)
      end

      private

      def option_call(record, name)
        option = options[name]
        option.respond_to?(:call) ? option.call(record) : option
      end

      def record_warning(record, attribute, name, value)
        record.warnings.add(attribute, :invalid, options.except(name).merge!(:value => value))
      end

      def check_options_validity(options, name)
        option = options[name]
        if option && !option.is_a?(Regexp) && !option.respond_to?(:call)
          raise ArgumentError, "A regular expression or a proc or lambda must be supplied as :#{name}"
        end
      end
    end

    module HelperMethods
      def cautions_format_of(*attr_names)
        cautions_with FormatCautioner, _merge_attributes(attr_names)
      end
    end
  end
end
