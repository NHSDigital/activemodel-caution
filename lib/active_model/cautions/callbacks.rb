module ActiveModel
  module Cautions
    module Callbacks
      extend ActiveSupport::Concern

      included do
        include ActiveSupport::Callbacks
        define_callbacks :cautions,
                         terminator: deprecated_false_terminator,
                         skip_after_callbacks_if_terminated: true,
                         scope: [:kind, :name]
      end

      module ClassMethods
        def before_cautions(*args, &block)
          options = args.last
          if options.is_a?(Hash) && options[:on]
            options[:if] = Array(options[:if])
            options[:on] = Array(options[:on])
            options[:if].unshift ->(o) {
              options[:on].include? o.caution_context
            }
          end
          set_callback(:cautions, :before, *args, &block)
        end

        def after_cautions(*args, &block)
          options = args.extract_options!
          options[:prepend] = true
          options[:if] = Array(options[:if])
          if options[:on]
            options[:on] = Array(options[:on])
            options[:if].unshift ->(o) {
              options[:on].include? o.caution_context
            }
          end
          set_callback(:cautions, :after, *(args << options), &block)
        end
      end

    protected

      def run_cautions!
        _run_cautions_callbacks { super }
      end
    end
  end
end
