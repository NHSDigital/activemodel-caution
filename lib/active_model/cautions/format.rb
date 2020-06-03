module ActiveModel
  module Cautions
    class FormatCautioner < EachCautioner # :nodoc:
      def caution_each(record, attribute, value)
        if options[:with]
          regexp = option_call(record, :with)
          record_warning(record, attribute, :with, value) if !value.to_s&.match?(regexp)
        elsif options[:without]
          regexp = option_call(record, :without)
          record_warning(record, attribute, :without, value) if regexp.match?(value.to_s)
        end
      end

      def check_validity!
        unless options.include?(:with) ^ options.include?(:without)  # ^ == xor, or "exclusive or"
          raise ArgumentError, "Either :with or :without must be supplied (but not both)"
        end

        check_options_validity :with
        check_options_validity :without
      end

      private

      def option_call(record, name)
        option = options[name]
        option.respond_to?(:call) ? option.call(record) : option
      end

      def record_warning(record, attribute, name, value)
        record.warnings.add(attribute, :invalid, options.except(name).merge!(value: value))
      end

      def check_options_validity(name)
        if option = options[name]
          if option.is_a?(Regexp)
            if options[:multiline] != true && regexp_using_multiline_anchors?(option)
              raise ArgumentError, "The provided regular expression is using multiline anchors (^ or $), " \
              "which may present a security risk. Did you mean to use \\A and \\z, or forgot to add the " \
              ":multiline => true option?"
            end
          elsif !option.respond_to?(:call)
            raise ArgumentError, "A regular expression or a proc or lambda must be supplied as :#{name}"
          end
        end
      end

      def regexp_using_multiline_anchors?(regexp)
        source = regexp.source
        source.start_with?("^") || (source.end_with?("$") && !source.end_with?("\\$"))
      end
    end

    module HelperMethods
      def cautions_format_of(*attr_names)
        cautions_with FormatCautioner, _merge_attributes(attr_names)
      end
    end
  end
end
