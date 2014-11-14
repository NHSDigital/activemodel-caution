# -*- coding: utf-8 -*-
# Modified active_model/.../errors.rb

require 'active_support/core_ext/array/wrap'
require 'active_support/core_ext/array/conversions'
require 'active_support/core_ext/string/inflections'
require 'active_support/core_ext/object/blank'
require 'active_support/core_ext/hash/reverse_merge'
require 'active_support/ordered_hash'

module ActiveModel
  class Warnings
    include Enumerable

    CALLBACKS_OPTIONS = [:if, :unless, :on, :allow_nil, :allow_blank]

    attr_reader :messages, :active

    def initialize(base)
      @base     = base
      @messages = ActiveSupport::OrderedHash.new
      @active   = ActiveSupport::OrderedHash.new
    end

    def initialize_dup(other)
      @messages = other.messages.dup
      @active   = other.active.dup
    end

    # Backport dup from 1.9 so that #initialize_dup gets called
    unless Object.respond_to?(:initialize_dup)
      def dup # :nodoc:
        copy = super
        copy.initialize_dup(self)
        copy
      end
    end

    # Clear the messages
    def clear
      messages.clear
      active.clear
    end

    def include?(warning)
      (v = messages[warning]) && v.any?
    end

    # Get messages for +key+
    def get(key)
      messages[key]
    end

    # Set messages for +key+ to +value+
    def set(key, value)
      messages[key] = value
    end

    # Delete messages for +key+
    def delete(key)
      messages.delete(key)
    end

    def [](attribute)
      get(attribute.to_sym) || set(attribute.to_sym, [])
    end

    def []=(attribute, warning)
      self[attribute] << warning
    end

    def each
      messages.each_key do |attribute|
        self[attribute].each { |warning| yield attribute, warning }
      end
    end

    def size
      values.flatten.size
    end

    # Returns all message values
    def values
      messages.values
    end

    # Returns all message keys
    def keys
      messages.keys
    end

    def to_a
      full_messages
    end

    def count
      to_a.size
    end

    # Returns true if no errors are found, false otherwise.
    def empty?
      all? { |k, v| v && v.empty? }
    end
    alias_method :blank?, :empty?

    def to_xml(options={})
      to_a.to_xml options.reverse_merge(:root => "warnings", :skip_types => true)
    end

    def as_json(options=nil)
      to_hash
    end

    def to_hash
      messages.dup
    end

    def add(attribute, message = nil, options = {})
      message ||= :invalid

      if message.is_a?(Symbol)
        message = generate_message(attribute, message, options.except(*CALLBACKS_OPTIONS))
      elsif message.is_a?(Proc)
        message = message.call
      end

      if options[:active]
        (@active[attribute.to_sym] ||= []) << message
      end

      self[attribute] << message
    end

    def add_on_empty(attributes, options = {})
      [attributes].flatten.each do |attribute|
        value = @base.send(:read_attribute_for_cautioning, attribute)
        is_empty = value.respond_to?(:empty?) ? value.empty? : false
        add(attribute, :empty, options) if value.nil? || is_empty
      end
    end

    def add_on_blank(attributes, options = {})
      [attributes].flatten.each do |attribute|
        value = @base.send(:read_attribute_for_cautioning, attribute)
        add(attribute, :blank, options) if value.blank?
      end
    end

    def passive
      passive = {}

      @messages.each do |attribute, attr_messages|
        active = (@active[attribute] || []) & attr_messages
        others = attr_messages - active

        passive[attribute] = others if others.any?
      end

      passive
    end

    def full_messages
      map { |attribute, message|
        if attribute == :base
          message
        else
          attr_name = attribute.to_s.gsub('.', '_').humanize
          attr_name = @base.class.human_attribute_name(attribute, :default => attr_name)

          I18n.t(:"warnings.format", {
            :default   => "%{attribute} %{message}",
            :attribute => attr_name,
            :message   => message
          })
        end
      }
    end

    def active_messages
      msgs = []

      @active.each do |attribute, messages|
        messages.each do |message|
          if attribute == :base
            message
          else
            attr_name = attribute.to_s.gsub('.', '_').humanize
            attr_name = @base.class.human_attribute_name(attribute, :default => attr_name)

            msgs << I18n.t(:"warnings.format", {
              :default   => "%{attribute} %{message}",
              :attribute => attr_name,
              :message   => message
            })
          end
        end
      end

      msgs
    end

    def generate_message(attribute, type = :invalid, options = {})
      type = options.delete(:message) if options[:message].is_a?(Symbol)

      defaults = @base.class.lookup_ancestors.map do |klass|
        [ :"#{@base.class.i18n_scope}.warnings.models.#{klass.model_name.i18n_key}.attributes.#{attribute}.#{type}",
          :"#{@base.class.i18n_scope}.warnings.models.#{klass.model_name.i18n_key}.#{type}" ]
      end

      defaults << options.delete(:message)
      defaults << :"#{@base.class.i18n_scope}.warnings.messages.#{type}"
      defaults << :"warnings.attributes.#{attribute}.#{type}"
      defaults << :"warnings.messages.#{type}"

      defaults.compact!
      defaults.flatten!

      key = defaults.shift
      value = (attribute != :base ? @base.send(:read_attribute_for_cautioning, attribute) : nil)

      options = {
        :default => defaults,
        :model => @base.class.model_name.human,
        :attribute => @base.class.human_attribute_name(attribute),
        :value => value
      }.merge(options)

      I18n.translate(key, options)
    end
  end
end
