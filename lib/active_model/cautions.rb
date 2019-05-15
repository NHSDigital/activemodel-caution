# Modified version of ActiveModel Validations (version 5.1.0)
# to provide warning functionality to ActiveRecord model
# in the same way as errors.
#
# Implement warnings in the model using the caution helper, e.g.
#
# caution :warn_against_large_tumour
#
# def warn_against_large_tumour
#   warnings.add(:tumoursize, 'is quite big') if tumoursize && tumoursize > 250
# end

require 'active_support/core_ext/array/extract_options'

module ActiveModel
  module Cautions
    extend ActiveSupport::Concern

    included do
      extend ActiveModel::Naming
      extend ActiveModel::Callbacks
      extend ActiveModel::Translation

      extend  HelperMethods
      include HelperMethods

      attr_accessor :caution_context
      private :caution_context=
      define_callbacks :caution, scope: :name

      class_attribute :_cautioners, instance_writer: false, default: Hash.new { |h, k| h[k] = [] }
    end

    module ClassMethods
      def cautions_each(*attr_names, &block)
        cautions_with BlockCautioner, _merge_attributes(attr_names), &block
      end

      VALID_OPTIONS_FOR_CAUTION = [:on, :if, :unless, :prepend].freeze # :nodoc:

      def caution(*args, &block)
        options = args.extract_options!

        if args.all? { |arg| arg.is_a?(Symbol) }
          options.each_key do |k|
            unless VALID_OPTIONS_FOR_CAUTION.include?(k)
              raise ArgumentError.new("Unknown key: #{k.inspect}. Valid keys are: #{VALID_OPTIONS_FOR_CAUTION.map(&:inspect).join(', ')}. Perhaps you meant to call `cautions` instead of `caution`?")
            end
          end
        end

        if options.key?(:on)
          options = options.dup
          options[:on] = Array(options[:on])
          options[:if] = Array(options[:if])
          options[:if].unshift ->(o) {
            !(options[:on] & Array(o.caution_context)).empty?
          }
        end

        set_callback(:caution, *args, options, &block)
      end

      def cautioners
        _cautioners.values.flatten.uniq
      end

      def clear_cautioners!
        reset_callbacks(:caution)
        _cautioners.clear
      end

      def cautioners_on(*attributes)
        attributes.flat_map do |attribute|
          _cautioners[attribute.to_sym]
        end
      end

      def attribute_method?(attribute)
        method_defined?(attribute)
      end

      def inherited(base) #:nodoc:
        dup = _cautioners.dup
        base._cautioners = dup.each { |k, v| dup[k] = v.dup }
        super
      end
    end

    def initialize_dup(other) #:nodoc:
      @errors = nil
      super
    end

    def warnings
      @warnings ||= Warnings.new(self)
    end

    def safe?(context = nil)
      current_context, self.caution_context = caution_context, context
      warnings.clear
      run_cautions!
    ensure
      self.caution_context = current_context
    end

    alias_method :caution, :safe?

    def unsafe?(context = nil)
      !safe?(context)
    end

    def caution!(context = nil)
      safe?(context) || raise_caution_error
    end


    # By default, reads `attribute` unless :value was specified, which
    # can be a Proc (called with the record) or just a plain value.
    def read_attribute_for_cautioning(attribute, options = {})
      if options.key?(:rawtext_value)
        # Shortcut for extracting a rawtext value from the record:
        raise(ArgumentError, 'no rawtext available') unless respond_to?(:rawtext)
        (rawtext || {})[options[:rawtext_value]]
      elsif options.key?(:value)
        # Option to provide a lambda:
        options[:value].respond_to?(:call) ? options[:value][self] : options[:value]
      else
        send(attribute)
      end
    end

  private

    def run_cautions! #:nodoc:
      run_callbacks :caution
      warnings.empty?
    end

    def raise_caution_error
      raise(CautionError.new(self))
    end
  end

  class CautionError < StandardError
    attr_reader :model

    def initialize(model)
      @model = model
      warnings = @model.warnings.full_messages.join(", ")
      super(I18n.t(:"#{@model.class.i18n_scope}.warnings.messages.model_unsafe", warnings: warnings, default: :"warnings.messages.model_unsafe"))
    end
  end
end

Dir[File.dirname(__FILE__) + "/cautions/*.rb"].each { |file| require file }
