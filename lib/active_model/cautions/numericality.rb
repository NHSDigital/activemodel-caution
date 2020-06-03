require 'bigdecimal/util'

module ActiveModel
  module Cautions
    class NumericalityCautioner < EachCautioner # :nodoc:
      CHECKS = { greater_than: :>, greater_than_or_equal_to: :>=,
                 equal_to: :==, less_than: :<, less_than_or_equal_to: :<=,
                 odd: :odd?, even: :even?, other_than: :!= }.freeze

      RESERVED_OPTIONS = CHECKS.keys + [:only_integer]

      INTEGER_REGEX = /\A[+-]?\d+\z/

      HEXADECIMAL_REGEX = /\A[+-]?0[xX]/

      def check_validity!
        keys = CHECKS.keys - [:odd, :even]
        options.slice(*keys).each do |option, value|
          unless value.is_a?(Numeric) || value.is_a?(Proc) || value.is_a?(Symbol)
            raise ArgumentError, ":#{option} must be a number, a symbol or a proc"
          end
        end
      end

      def caution_each(record, attr_name, value)
        came_from_user = :"#{attr_name}_came_from_user?"

        if record.respond_to?(came_from_user)
          if record.public_send(came_from_user)
            raw_value = record.read_attribute_before_type_cast(attr_name)
          elsif record.respond_to?(:read_attribute)
            raw_value = record.read_attribute(attr_name)
          end
        else
          before_type_cast = :"#{attr_name}_before_type_cast"
          if record.respond_to?(before_type_cast)
            raw_value = record.public_send(before_type_cast)
          end
        end
        raw_value ||= value

        if record_attribute_changed_in_place?(record, attr_name)
          raw_value = value
        end

        unless is_number?(raw_value)
          record.warnings.add(attr_name, :not_a_number, filtered_options(raw_value))
          return
        end

        if allow_only_integer?(record) && !is_integer?(raw_value)
          record.warnings.add(attr_name, :not_an_integer, filtered_options(raw_value))
          return
        end

        value = parse_as_number(raw_value)

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

            option_value = parse_as_number(option_value)

            unless value.send(CHECKS[option], option_value)
              record.warnings.add(attr_name, option, filtered_options(value).merge!(count: option_value))
            end
          end
        end
      end

    private

      def is_number?(raw_value)
        !parse_as_number(raw_value).nil?
      rescue ArgumentError, TypeError
        false
      end

      def parse_as_number(raw_value)
        if raw_value.is_a?(Float)
          raw_value.to_d
        elsif raw_value.is_a?(Numeric)
          raw_value
        elsif is_integer?(raw_value)
          raw_value.to_i
        elsif !is_hexadecimal_literal?(raw_value)
          Kernel.Float(raw_value).to_d
        end
      end

      def is_integer?(raw_value)
        INTEGER_REGEX.match?(raw_value.to_s)
      end

      def is_hexadecimal_literal?(raw_value)
        HEXADECIMAL_REGEX.match?(raw_value.to_s)
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
