# Modified version of ActiveModel Validations (version 3.0.10)
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
require 'active_support/core_ext/array/wrap'
require 'active_support/core_ext/class/attribute'
require 'active_support/core_ext/hash/keys'
require 'active_support/core_ext/hash/except'

require 'active_model/cautioner'
require 'active_model/cautions/callbacks'
require 'active_model/warnings'

module ActiveModel
  module Caution
    extend ActiveSupport::Concern
    include ActiveSupport::Callbacks

    included do
      extend ActiveModel::Translation

      extend  HelperMethods
      include HelperMethods

      attr_accessor :caution_context
      define_callbacks :caution, :scope => :name

      class_attribute :_cautioners
      self._cautioners = Hash.new { |h,k| h[k] = [] }
    end


    module ClassMethods
      def cautions_each(*attr_names, &block)
        options = attr_names.extract_options!.symbolize_keys
        cautions_with BlockCautioner, options.merge(:attributes => attr_names.flatten), &block
      end

      def caution(*args, &block)
        options = args.extract_options!
        if options.key?(:on)
          options = options.dup
          options[:if] = Array.wrap(options[:if])
          options[:if] << "caution_context == :#{options[:on]}"
        end
        args << options
        set_callback(:caution, *args, &block)
      end

      def cautioners
        _cautioners.values.flatten.uniq
      end

      def cautioners_on(attribute)
        _cautioners[attribute.to_sym]
      end

      # Check if method is an attribute method or not.
      def attribute_method?(attribute)
        method_defined?(attribute)
      end

      def inherited(base)
        dup = _cautioners.dup
        base._cautioners = dup.each { |k, v| dup[k] = v.dup }
        super
      end
    end


    # Returns the Warnings object that holds all information about attribute warning messages.
    def warnings
      @warnings ||= Warnings.new(self)
    end
    

    # Runs caution and returns true if no warnings were added otherwise false.
    def safe?(context = nil)
      current_context, self.caution_context = caution_context, context
      warnings.clear
      run_cautions!
    ensure
      self.caution_context = current_context
    end

    # Performs the opposite of <tt>safe?</tt>. Returns true if errors were added,
    # false otherwise.
    def unsafe?(context = nil)
      !safe?(context)
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

    protected

    def run_cautions!
      _run_caution_callbacks
      warnings.empty?
    end

  end
end

Dir[File.dirname(__FILE__) + "/cautions/*.rb"].sort.each do |path|
  filename = File.basename(path)
  require "active_model/cautions/#{filename}"
end

require 'active_support/i18n'
I18n.load_path << File.dirname(__FILE__) + '/locale/en.yml'
