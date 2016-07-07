module ActiveModel
  module Cautions
    class WithCautioner < EachCautioner # :nodoc:
      def caution_each(record, attr, val)
        method_name = options[:with]

        if record.method(method_name).arity == 0
          record.send method_name
        else
          record.send method_name, attr
        end
      end
    end

    module ClassMethods
      def cautions_with(*args, &block)
        options = args.extract_options!
        options[:class] = self

        args.each do |klass|
          cautioner = klass.new(options, &block)

          if cautioner.respond_to?(:attributes) && !cautioner.attributes.empty?
            cautioner.attributes.each do |attribute|
              _cautioners[attribute.to_sym] << cautioner
            end
          else
            _cautioners[nil] << cautioner
          end

          caution(cautioner, options)
        end
      end
    end

    def cautions_with(*args, &block)
      options = args.extract_options!
      options[:class] = self.class

      args.each do |klass|
        cautioner = klass.new(options, &block)
        cautioner.caution(self)
      end
    end
  end
end
