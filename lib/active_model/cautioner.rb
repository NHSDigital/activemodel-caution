require "active_support/core_ext/module/anonymous"

module ActiveModel
  class Cautioner
    attr_reader :options

    def self.kind
      @kind ||= name.split('::').last.underscore.chomp('_caution').to_sym unless anonymous?
    end

    def initialize(options = {})
      @options = options.except(:class).freeze
    end

    def kind
      self.class.kind
    end

    def caution(record)
      raise NotImplementedError, "Subclasses must implement a caution(record) method."
    end
  end

  class EachCautioner < Cautioner #:nodoc:
    attr_reader :attributes

    def initialize(options)
      @attributes = Array(options.delete(:attributes))
      raise ArgumentError, ":attributes cannot be blank" if @attributes.empty?
      super
      check_validity!
    end

    def caution(record)
      attributes.each do |attribute|
        value = record.read_attribute_for_cautioning(attribute, options)
        next if (value.nil? && options[:allow_nil]) || (value.blank? && options[:allow_blank])
        caution_each(record, attribute, value)
      end
    end

    def caution_each(record, attribute, value)
      raise NotImplementedError, "Subclasses must implement a caution_each(record, attribute, value) method"
    end

    def check_validity!
    end
  end

  class BlockCautioner < EachCautioner #:nodoc:
    def initialize(options, &block)
      @block = block
      super
    end

    private

    def caution_each(record, attribute, value)
      @block.call(record, attribute, value)
    end
  end
end
