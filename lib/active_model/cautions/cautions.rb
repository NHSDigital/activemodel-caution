require 'active_support/core_ext/hash/slice'

module ActiveModel
  module Cautions
    module ClassMethods
      def cautions(*attributes)
        defaults = attributes.extract_options!.dup
        cautions = defaults.slice!(*_cautions_default_keys)

        raise ArgumentError, "You need to supply at least one attribute" if attributes.empty?
        raise ArgumentError, "You need to supply at least one caution" if cautions.empty?

        defaults[:attributes] = attributes

        cautions.each do |key, options|
          next unless options
          key = "#{key.to_s.camelize}Cautioner"

          begin
            cautioner = key.include?('::') ? key.constantize : const_get(key)
          rescue NameError
            raise ArgumentError, "Unknown cautioner: '#{key}'"
          end

          cautions_with(cautioner, defaults.merge(_parse_cautions_options(options)))
        end
      end

      def cautions!(*attributes)
        options = attributes.extract_options!
        options[:strict] = true
        cautions(*(attributes << options))
      end

    private

      def _cautions_default_keys
        [:if, :unless, :on, :allow_blank, :allow_nil , :strict]
      end

      def _parse_cautions_options(options)
        case options
        when TrueClass
          {}
        when Hash
          options
        when Range, Array
          { in: options }
        else
          { with: options }
        end
      end
    end
  end
end
