module ActiveModel
  module Cautions
    module SafetyDecision
      extend ActiveSupport::Concern

      # Add an additional error post-validation if
      # ther record was otherwise valid, but has
      # unconfirmed active warnings.
      def valid?(*args)
        # Validations can add warnings too, start with a
        # clean slate. We preserve those warnings when
        # checking for active cautions.
        return super unless respond_to?(:warnings)

        warnings.clear
        super && no_unconfirmed_active_cautions?
      end

      # Add a validation failure if the record
      # has active warnings that the user has not
      # given explicit permission for:
      def no_unconfirmed_active_cautions?
        if confirmed_safe?
          true
        else
          # Preserve warnings added by validations:
          cached_warnings = warnings.to_hash

          # Run the cautions as part of the validations,
          # but only if the user has not already decided:
          safe?

          # Re-apply any cached warnings:
          cached_warnings.each do |attr, messages|
            messages.each do |msg|
              warnings.add(attr, msg) unless warnings[attr].include?(msg)
            end
          end

          if warnings.active.any?
            warnings_need_confirmation!
            errors.add(:base, 'The following warnings need confirmation: ' + warnings.active_messages.to_sentence)
          end

          !warnings_need_confirmation?
        end
      end

      # Did validations fail because the user
      # needs to confirm warnings have been read?
      def warnings_need_confirmation?
        @_active_warnings_confirm_needed ||= false
      end

      def warnings_need_confirmation!
        # There is no mechanism to unset this flag.
        @_active_warnings_confirm_needed = true
      end

      def active_warnings_confirm_decision
        @active_warnings_confirm_decision ||= false
      end

      def active_warnings_confirm_decision=(value)
        # A decision has been made:
        @_active_warnings_confirm_needed  = false
        # This is the decision:
        @active_warnings_confirm_decision = !!value
      end

      # The result of the user's decision:
      def confirmed_safe?
        active_warnings_confirm_decision
      end

    end
  end
end
