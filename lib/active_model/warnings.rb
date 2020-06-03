require 'active_support/core_ext/array/conversions'
require 'active_support/core_ext/string/inflections'
require 'active_support/core_ext/object/deep_dup'
require 'active_support/core_ext/string/filters'

module ActiveModel
  class Warnings
    include Enumerable

    CALLBACKS_OPTIONS = [:if, :unless, :on, :allow_nil, :allow_blank, :strict]
    MESSAGE_OPTIONS = [:message]

    class << self
      attr_accessor :i18n_customize_full_message # :nodoc:
    end
    self.i18n_customize_full_message = false

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

    def merge!(other)
      @messages.merge!(other.messages) { |_, ary1, ary2| ary1 + ary2 }
      @details.merge!(other.details) { |_, ary1, ary2| ary1 + ary2 }
      @active.merge!(other.active) { |_, ary1, ary2| ary1 + ary2 }
    end

    def slice!(*keys)
      keys = keys.map(&:to_sym)
      @details.slice!(*keys)
      @messages.slice!(*keys)
    end

    def clear
      messages.clear
      details.clear
      active.clear
    end

    def include?(attribute)
      attribute = attribute.to_sym
      messages.key?(attribute) && messages[attribute].present?
    end
    alias :has_key? :include?
    alias :key? :include?

    def delete(key)
      attribute = key.to_sym
      active.delete(attribute)
      details.delete(attribute)
      messages.delete(attribute)
    end

    def [](attribute)
      messages[attribute.to_sym]
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
      messages.select do |key, value|
        !value.empty?
      end.values
    end

    def keys
      messages.select do |key, value|
        !value.empty?
      end.keys
    end

    def empty?
      size.zero?
    end
    alias :blank? :empty?

    def to_xml(options = {})
      to_a.to_xml({ root: "warnings", skip_types: true }.merge!(options))
    end

    def as_json(options = nil)
      to_hash(options && options[:full_messages])
    end

    def to_hash(full_messages = false)
      if full_messages
        messages.each_with_object({}) do |(attribute, array), messages|
          messages[attribute] = array.map { |message| full_message(attribute, message) }
        end
      else
        without_default_proc(messages)
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

    def added?(attribute, message = :invalid, options = {})
      message = message.call if message.respond_to?(:call)

      if message.is_a? Symbol
        details[attribute.to_sym].include? normalize_detail(message, options)
      else
        self[attribute].include? message
      end
    end

    def of_kind?(attribute, message = :invalid)
      message = message.call if message.respond_to?(:call)

      if message.is_a? Symbol
        details[attribute.to_sym].map { |c| c[:warning] }.include? message
      else
        self[attribute].include? message
      end
    end

    def passive
      @messages.each_with_object(apply_default_array({})) do |(attribute, messages), passive|
        attribute = attribute.to_sym
        messages.each do |message|
          passive[attribute] << message unless @active.key?(attribute) && @active[attribute].include?(message)
        end
      end
    end

    def active_messages
      messages = []

      @active.each_key do |attribute|
        @active[attribute.to_sym].each { |warning| messages << full_message(attribute, warning ) }
      end

      messages
    end

    def full_messages
      map { |attribute, message| full_message(attribute, message) }
    end
    alias :to_a :full_messages

    def full_messages_for(attribute)
      attribute = attribute.to_sym
      messages[attribute].map { |message| full_message(attribute, message) }
    end

    def full_message(attribute, message)
      return message if attribute == :base
      attribute = attribute.to_s

      if self.class.i18n_customize_full_message && @base.class.respond_to?(:i18n_scope)
        attribute = attribute.remove(/\[\d\]/)
        parts = attribute.split(".")
        attribute_name = parts.pop
        namespace = parts.join("/") unless parts.empty?
        attributes_scope = "#{@base.class.i18n_scope}.warnings.models"

        if namespace
          defaults = @base.class.lookup_ancestors.map do |klass|
            [
              :"#{attributes_scope}.#{klass.model_name.i18n_key}/#{namespace}.attributes.#{attribute_name}.format",
              :"#{attributes_scope}.#{klass.model_name.i18n_key}/#{namespace}.format",
            ]
          end
        else
          defaults = @base.class.lookup_ancestors.map do |klass|
            [
              :"#{attributes_scope}.#{klass.model_name.i18n_key}.attributes.#{attribute_name}.format",
              :"#{attributes_scope}.#{klass.model_name.i18n_key}.format",
            ]
          end
        end

        defaults.flatten!
      else
        defaults = []
      end

      defaults << :"warnings.format"
      defaults << "%{attribute} %{message}"

      attr_name = attribute.tr(".", "_").humanize
      attr_name = @base.class.human_attribute_name(attribute, default: attr_name)
      I18n.t(defaults.shift,
        default:   defaults,
        attribute: attr_name,
        message:   message)
    end

    def generate_message(attribute, type = :invalid, options = {})
      type = options.delete(:message) if options[:message].is_a?(Symbol)
      value = (attribute != :base ? @base.send(:read_attribute_for_cautioning, attribute) : nil)

      options = {
        model: @base.model_name.human,
        attribute: @base.class.human_attribute_name(attribute),
        value: value,
        object: @base
      }.merge!(options)

      if @base.class.respond_to?(:i18n_scope)
        i18n_scope = @base.class.i18n_scope.to_s
        defaults = @base.class.lookup_ancestors.map do |klass|
          [ :"#{i18n_scope}.warnings.models.#{klass.model_name.i18n_key}.attributes.#{attribute}.#{type}",
            :"#{i18n_scope}.warnings.models.#{klass.model_name.i18n_key}.#{type}" ]
        end
        defaults << :"#{i18n_scope}.warnings.messages.#{type}"

        catch(:exception) do
          translation = I18n.translate(defaults.first, **options.merge(default: defaults.drop(1), throw: true))
          return translation unless translation.nil?
        end unless options[:message]
      else
        defaults = []
      end

      defaults << :"warnings.attributes.#{attribute}.#{type}"
      defaults << :"warnings.messages.#{type}"

      defaults.compact!
      defaults.flatten!

      key = defaults.shift
      defaults = options.delete(:message) if options[:message]
      options[:default] = defaults

      I18n.translate(key, **options)
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

    def init_with(coder) # :nodoc:
      coder.map.each { |k, v| instance_variable_set(:"@#{k}", v) }
      @details ||= {}
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
