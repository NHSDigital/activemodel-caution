# This definition duplicates the one from ActiveModel::Validations, but also
# acts as the namespace for (e.g.) `cautions_numericality_of`.
module ActiveModel
  module Cautions
    module HelperMethods # :nodoc:
      private
        def _merge_attributes(attr_names)
          options = attr_names.extract_options!.symbolize_keys
          attr_names.flatten!
          options[:attributes] = attr_names
          options
        end
    end
  end
end
