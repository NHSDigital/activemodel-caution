module ActiveModel
  module Cautions
    class NumericalityCautioner < EachCautioner # :nodoc:
      CHECKS = { greater_than: :>, greater_than_or_equal_to: :>=,
                 equal_to: :==, less_than: :<, less_than_or_equal_to: :<=,
                 odd: :odd?, even: :even?, other_than: :!= }.freeze

      RESERVED_OPTIONS = CHECKS.keys + [:only_integer]

      def check_validity!
        keys = CHECKS.keys - [:odd, :even]
        options.slice(*keys).each do |option, value|
          unless value.is_a?(Numeric) || value.is_a?(Proc) || value.is_a?(Symbol)
            raise ArgumentError, ":#{option} must be a number, a symbol or a proc"
          end
        end
      end

      def caution_each(record, attr_name, value)
        before_type_cast = :"#{attr_name}_before_type_cast"

        raw_value = record.send(before_type_cast) if record.respond_to?(before_type_cast) && record.send(before_type_cast) != value
        raw_value ||= value

        if record_attribute_changed_in_place?(record, attr_name)
          raw_value = value
        end

        return if options[:allow_nil] && raw_value.nil?

        unless is_number?(raw_value)
          record.warnings.add(attr_name, :not_a_number, filtered_options(raw_value))
          return
        end

        if allow_only_integer?(record) && !is_integer?(raw_value)
          record.warnings.add(attr_name, :not_an_integer, filtered_options(raw_value))
          return
        end

        unless raw_value.is_a?(Numeric)
          value = parse_raw_value_as_a_number(raw_value)
        end

        options.slice(*CHECKS.keys).each do |option, option_value|
          case option
          when :odd, :even
            unless value.to_i.send(CHECKS[option])
              record.warnings.add(attr_name, option, filtered_options(value))
            end
          else
            case option_value
            when Proc
              option_value = option_value.call(record)
            when Symbol
              option_value = record.send(option_value)
            end

            unless value.send(CHECKS[option], option_value)
              record.warnings.add(attr_name, option, filtered_options(value).merge!(count: option_value))
            end
          end
        end
      end

    protected

      def is_number?(raw_value)
        !parse_raw_value_as_a_number(raw_value).nil?
      rescue ArgumentError, TypeError
        false
      end

      def parse_raw_value_as_a_number(raw_value)
        Kernel.Float(raw_value) if raw_value !~ /\A0[xX]/
      end

      def is_integer?(raw_value)
        /\A[+-]?\d+\z/ === raw_value.to_s
      end

      def filtered_options(value)
        filtered = options.except(*RESERVED_OPTIONS)
        filtered[:value] = value
        filtered
      end

      def allow_only_integer?(record)
        case options[:only_integer]
        when Symbol
          record.send(options[:only_integer])
        when Proc
          options[:only_integer].call(record)
        else
          options[:only_integer]
        end
      end

      private

      def record_attribute_changed_in_place?(record, attr_name)
        record.respond_to?(:attribute_changed_in_place?) &&
          record.attribute_changed_in_place?(attr_name.to_s)
      end
    end

    module HelperMethods
      def cautions_numericality_of(*attr_names)
        cautions_with NumericalityCautioner, _merge_attributes(attr_names)
      end
    end
  end
end
