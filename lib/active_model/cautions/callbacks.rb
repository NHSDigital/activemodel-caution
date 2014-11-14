require 'active_support/callbacks'

module ActiveModel
  module Caution
    module Callbacks
      extend ActiveSupport::Concern

      included do
        include ActiveSupport::Callbacks
        define_callbacks :cautions, :terminator => "result == false", :scope => [:kind, :name]
      end

      module ClassMethods
        def before_cautions(*args, &block)
          options = args.extract_options!
          if options.is_a?(Hash) && options[:on]
            options[:if] = Array.wrap(options[:if])
            options[:if] << "self.caution_context == :#{options[:on]}"
          end
          set_callback(:cautions, :before, *(args << options), &block)
        end

        def after_cautions(*args, &block)
          options = args.extract_options!
          options[:prepend] = true
          options[:if] = Array.wrap(options[:if])
          options[:if] << "!halted"
          options[:if] << "self.caution_context == :#{options[:on]}" if options[:on]
          set_callback(:cautions, :after, *(args << options), &block)
        end

        [:before, :after].each do |type|
          [:create, :update].each do |on|
            class_eval <<-RUBY
              def #{type}_caution_on_#{on}(*args, &block)
                msg = "#{type}_caution_on_#{on} is deprecated. Please use #{type}_caution(arguments, :on => :#{on}"
                ActiveSupport::Deprecation.warn(msg, caller)
                options = args.extract_options!
                options[:on] = :#{on}
                #{type}_caution(*args.push(options), &block)
              end
            RUBY
          end
        end
      end

    protected

      def run_cautions!
        _run_cautions_callbacks { super }
      end
    end
  end
end
