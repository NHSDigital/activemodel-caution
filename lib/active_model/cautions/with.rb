module ActiveModel
  module Caution
    module HelperMethods
      private
        def _merge_attributes(attr_names)
          options = attr_names.extract_options!
          options.merge(:attributes => attr_names.flatten)
        end
    end

    module ClassMethods
      def cautions_with(*args, &block)
        options = args.extract_options!
        args.each do |klass|
          cautioner = klass.new(options, &block)
          cautioner.setup(self) if cautioner.respond_to?(:setup)

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
      args.each do |klass|
        cautioner = klass.new(options, &block)
        cautioner.caution(self)
      end
    end
  end
end
