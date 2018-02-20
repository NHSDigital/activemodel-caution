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
          options[:if] = Array(options[:if])

          if options.key?(:on)
            options[:if].unshift ->(o) {
              !(Array(options[:on]) & Array(o.caution_context)).empty?
            }
          end

          args << options
          set_callback(:cautions, :before, *args, &block)
        end

        def after_cautions(*args, &block)
          options = args.extract_options!
          options[:prepend] = true
          options[:if] = Array(options[:if])

          if options.key?(:on)
            options[:if].unshift ->(o) {
              !(Array(options[:on]) & Array(o.caution_context)).empty?
            }
          end

          args << options
          set_callback(:cautions, :after, *args, &block)
        end
      end

    protected

      def run_cautions!
        run_callbacks(:cautions) { super }
      end
    end
  end
end
