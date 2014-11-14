module ActiveModel
  class Cautioner
    attr_reader :options

    def self.kind
      @kind ||= name.split('::').last.underscore.sub(/_validator$/, '').to_sym unless anonymous?
    end

    def initialize(options)
      @options = options.freeze
    end

    def kind
      self.class.kind
    end

    def validate(record)
      raise NotImplementedError
    end
  end

  class EachCautioner < Cautioner
    attr_reader :attributes

    def initialize(options)
      @attributes = Array.wrap(options.delete(:attributes))
      raise ":attributes cannot be blank" if @attributes.empty?
      super
      check_safety!
    end

    def caution(record)
      attributes.each do |attribute|
        value = record.read_attribute_for_cautioning(attribute, options)
        next if (value.nil? && options[:allow_nil]) || (value.blank? && options[:allow_blank])
        caution_each(record, attribute, value)
      end
    end

    def caution_each(record, attribute, value)
      raise NotImplementedError
    end

    def check_safety!
    end
  end

  class BlockCautioner < EachCautioner
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
