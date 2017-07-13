require 'active_support/core_ext/array/conversions'
require 'active_support/core_ext/string/inflections'
require 'active_support/core_ext/object/deep_dup'
require 'active_support/core_ext/string/filters'

module ActiveModel
  class Warnings
    include Enumerable

    CALLBACKS_OPTIONS = [:if, :unless, :on, :allow_nil, :allow_blank, :strict]
    MESSAGE_OPTIONS = [:message]

    attr_reader :messages, :details
    attr_reader :active

    def initialize(base)
      @base     = base
      @messages = apply_default_array({})
      @details  = apply_default_array({})
      @active   = apply_default_array({})
    end

    def initialize_dup(other) # :nodoc:
      @messages = other.messages.dup
      @details  = other.details.deep_dup
      @active   = other.active.deep_dup
      super
    end

    def copy!(other) # :nodoc:
      @messages = other.messages.dup
      @details  = other.details.dup
      @active   = other.active.dup
    end

    def clear
      messages.clear
      details.clear
      active.clear
    end

    def include?(attribute)
      messages.key?(attribute) && messages[attribute].present?
    end
    alias :has_key? :include?
    alias :key? :include?

    def get(key)
      ActiveSupport::Deprecation.warn(<<-MESSAGE.squish)
        ActiveModel::Warnings#get is deprecated and will be removed in activemodel-caution 5.1.

        To achieve the same use model.warnings[:#{key}].
      MESSAGE

      messages[key]
    end

    def set(key, value)
      ActiveSupport::Deprecation.warn(<<-MESSAGE.squish)
        ActiveModel::Warnings#set is deprecated and will be removed in activemodel-caution 5.1.

        Use model.warnings.add(:#{key}, #{value.inspect}) instead.
      MESSAGE

      messages[key] = value
    end

    def delete(key)
      active.delete(key)
      details.delete(key)
      messages.delete(key)
    end

    def [](attribute)
      messages[attribute.to_sym]
    end

    def []=(attribute, warning)
      ActiveSupport::Deprecation.warn(<<-MESSAGE.squish)
        ActiveModel::Warnings#[]= is deprecated and will be removed in activemodel-caution 5.1.

        Use model.warnings.add(:#{attribute}, #{warning.inspect}) instead.
      MESSAGE

      messages[attribute.to_sym] << warning
    end

    def each
      messages.each_key do |attribute|
        messages[attribute].each { |warning| yield attribute, warning }
      end
    end

    def size
      values.flatten.size
    end
    alias :count :size

    def values
      messages.values
    end

    def keys
      messages.keys
    end

    def empty?
      size.zero?
    end
    alias :blank? :empty?

    def to_xml(options={})
      to_a.to_xml({ root: "warnings", skip_types: true }.merge!(options))
    end

    def as_json(options=nil)
      to_hash(options && options[:full_messages])
    end

    def to_hash(full_messages = false)
      if full_messages
        self.messages.each_with_object({}) do |(attribute, array), messages|
          messages[attribute] = array.map { |message| full_message(attribute, message) }
        end
      else
        self.messages.dup
      end
    end

    def add(attribute, message = :invalid, options = {})
      message = message.call if message.respond_to?(:call)
      detail  = normalize_detail(message, options)
      message = normalize_message(attribute, message, options)
      if exception = options[:strict]
        exception = ActiveModel::StrictValidationFailed if exception == true
        raise exception, full_message(attribute, message)
      end

      active[attribute.to_sym]   << message if options[:active]
      details[attribute.to_sym]  << detail
      messages[attribute.to_sym] << message
    end

    def add_on_empty(attributes, options = {})
      ActiveSupport::Deprecation.warn(<<-MESSAGE.squish)
        ActiveModel::Warnings#add_on_empty is deprecated and will be removed in activemodel-caution 5.1.

        To achieve the same use:

          warnings.add(attribute, :empty, options) if value.nil? || value.empty?
      MESSAGE

      Array(attributes).each do |attribute|
        value = @base.send(:read_attribute_for_cautioning, attribute)
        is_empty = value.respond_to?(:empty?) ? value.empty? : false
        add(attribute, :empty, options) if value.nil? || is_empty
      end
    end

    def add_on_blank(attributes, options = {})
      ActiveSupport::Deprecation.warn(<<-MESSAGE.squish)
        ActiveModel::Warnings#add_on_blank is deprecated and will be removed in activemodel-caution 5.1.

        To achieve the same use:

          warnings.add(attribute, :empty, options) if value.blank?
      MESSAGE

      Array(attributes).each do |attribute|
        value = @base.send(:read_attribute_for_cautioning, attribute)
        add(attribute, :blank, options) if value.blank?
      end
    end

    def added?(attribute, message = :invalid, options = {})
      message = message.call if message.respond_to?(:call)
      message = normalize_message(attribute, message, options)
      self[attribute].include? message
    end

    def passive
      @messages.each_with_object(apply_default_array({})) do |(attribute, messages), passive|
        messages.each do |message|
          passive[attribute] << message unless @active.key?(attribute) && @active[attribute].include?(message)
        end
      end
    end

    def active_messages
      messages = []

      @active.each_key do |attribute|
        @active[attribute].each { |warning| messages << full_message(attribute, warning ) }
      end

      messages
    end

    def full_messages
      map { |attribute, message| full_message(attribute, message) }
    end
    alias :to_a :full_messages

    def full_messages_for(attribute)
      messages[attribute].map { |message| full_message(attribute, message) }
    end

    def full_message(attribute, message)
      return message if attribute == :base
      attr_name = attribute.to_s.tr('.', '_').humanize
      attr_name = @base.class.human_attribute_name(attribute, default: attr_name)
      I18n.t(:"warnings.format", {
        default:  "%{attribute} %{message}",
        attribute: attr_name,
        message:   message
      })
    end

    def generate_message(attribute, type = :invalid, options = {})
      type = options.delete(:message) if options[:message].is_a?(Symbol)

      if @base.class.respond_to?(:i18n_scope)
        defaults = @base.class.lookup_ancestors.map do |klass|
          [ :"#{@base.class.i18n_scope}.warnings.models.#{klass.model_name.i18n_key}.attributes.#{attribute}.#{type}",
            :"#{@base.class.i18n_scope}.warnings.models.#{klass.model_name.i18n_key}.#{type}" ]
        end
      else
        defaults = []
      end

      defaults << :"#{@base.class.i18n_scope}.warnings.messages.#{type}" if @base.class.respond_to?(:i18n_scope)
      defaults << :"warnings.attributes.#{attribute}.#{type}"
      defaults << :"warnings.messages.#{type}"

      defaults.compact!
      defaults.flatten!

      key = defaults.shift
      defaults = options.delete(:message) if options[:message]
      value = (attribute != :base ? @base.send(:read_attribute_for_cautioning, attribute) : nil)

      options = {
        default: defaults,
        model: @base.model_name.human,
        attribute: @base.class.human_attribute_name(attribute),
        value: value,
        object: @base
      }.merge!(options)

      I18n.translate(key, options)
    end

    def marshal_dump
      [@base, without_default_proc(@messages), without_default_proc(@details), without_default_proc(@active)]
    end

    def marshal_load(array)
      @base, @messages, @details, @active = array
      apply_default_array(@messages)
      apply_default_array(@details)
      apply_default_array(@active)
    end

  private
    def normalize_message(attribute, message, options)
      case message
      when Symbol
        generate_message(attribute, message, options.except(*CALLBACKS_OPTIONS))
      else
        message
      end
    end

    def normalize_detail(message, options)
      { warning: message }.merge(options.except(*CALLBACKS_OPTIONS + MESSAGE_OPTIONS))
    end

    def without_default_proc(hash)
      hash.dup.tap do |new_h|
        new_h.default_proc = nil
      end
    end

    def apply_default_array(hash)
      hash.default_proc = proc { |h, key| h[key] = [] }
      hash
    end
  end

  # class StrictValidationFailed < StandardError
  # end
  #
  # class RangeError < ::RangeError
  # end
  #
  # class UnknownAttributeError < NoMethodError
  #   attr_reader :record, :attribute
  #
  #   def initialize(record, attribute)
  #     @record = record
  #     @attribute = attribute
  #     super("unknown attribute '#{attribute}' for #{@record.class}.")
  #   end
  # end
end
