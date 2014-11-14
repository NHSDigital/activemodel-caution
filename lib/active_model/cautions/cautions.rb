require 'active_support/core_ext/hash/slice'

module ActiveModel

  module Caution
    module ClassMethods

      def cautions(*attributes)
        defaults = attributes.extract_options!
        cautioners  = defaults.slice!(:if, :unless, :on, :allow_blank, :allow_nil)

        raise ArgumentError, "You need to supply at least one attribute" if attributes.empty?
        raise ArgumentError, "Attribute names must be symbols" if attributes.any?{ |attribute| !attribute.is_a?(Symbol) }
        raise ArgumentError, "You need to supply at least one warning" if cautioners.empty?

        defaults.merge!(:attributes => attributes)

        cautioners.each do |key, options|
          begin
            cautioner = const_get("#{key.to_s.camelize}Cautioner")
          rescue NameError
            raise ArgumentError, "Unknown cautioner: '#{key}' - not validations have been implemented as cautions yet."
          end

          cautions_with(cautioner, defaults.merge(_parse_cautions_options(options)))
        end
      end

    protected

      def _parse_cautions_options(options) #:nodoc:
        case options
        when TrueClass
          {}
        when Hash
          options
        when Regexp
          { :with => options }
        when Range, Array
          { :in => options }
        else
          raise ArgumentError, "#{options.inspect} is an invalid option. Expecting true, Hash, Regexp, Range, or Array"
        end
      end
    end
  end
end
