module ActiveModel
  module Cautions
    module Callbacks
      extend ActiveSupport::Concern

      included do
        include ActiveSupport::Callbacks
        define_callbacks :cautions,
                         skip_after_callbacks_if_terminated: true,
                         scope: [:kind, :name]
      end

      module ClassMethods
        def before_cautions(*args, &block)
          options = args.extract_options!

          if options.key?(:on)
            options = options.dup
            options[:on] = Array(options[:on])
            options[:if] = Array(options[:if])
            options[:if].unshift ->(o) {
              !(options[:on] & Array(o.caution_context)).empty?
            }
          end

          set_callback(:cautions, :before, *args, options, &block)
        end

        def after_cautions(*args, &block)
          options = args.extract_options!
          options = options.dup
          options[:prepend] = true

          if options.key?(:on)
            options[:on] = Array(options[:on])
            options[:if] = Array(options[:if])
            options[:if].unshift ->(o) {
              !(options[:on] & Array(o.caution_context)).empty?
            }
          end

          set_callback(:cautions, :after, *args, options, &block)
        end
      end

    private

      def run_cautions!
        run_callbacks(:cautions) { super }
      end
    end
  end
end
