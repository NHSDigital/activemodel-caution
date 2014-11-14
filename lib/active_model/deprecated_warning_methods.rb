module ActiveModel
  module DeprecatedWarningMethods
    def on(attribute)
      message = "Warnings#on have been deprecated, use Warnings#[] instead.\n"
      message << "Also note that the behaviour of Warnings#[] has changed. Warnings#[] now always returns an Array. An empty Array is "
      message << "returned when there are no warning on the specified attribute."
      ActiveSupport::Deprecation.warn(message)

      warning = self[attribute]
      warning.size < 2 ? warning.first : warning
    end

    def on_base
      ActiveSupport::Deprecation.warn "Warnings#on_base have been deprecated, use Warnings#[:base] instead"
      ActiveSupport::Deprecation.silence { on(:base) }
    end

    def add_to_base(msg)
      ActiveSupport::Deprecation.warn "Warnings#add_to_base(msg) has been deprecated, use Warnings#add(:base, msg) instead"
      self[:base] << msg
    end

    def invalid?(attribute)
      ActiveSupport::Deprecation.warn "Warnings#invalid?(attribute) has been deprecated, use Warnings#[attribute].any? instead"
      self[attribute].any?
    end

    def each_full
      ActiveSupport::Deprecation.warn "Warnings#each_full has been deprecated, use Warnings#to_a.each instead"
      to_a.each { |error| yield error }
    end
  end
end
