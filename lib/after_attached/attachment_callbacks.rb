# frozen_string_literal: true

module AfterAttached
  module AttachmentCallbacks
    extend ActiveSupport::Concern

    included do
      class_attribute :_attachment_callbacks, default: {
        before_attached: {},
        after_attached: {},
        before_detached: {},
        after_detached: {}
      }
    end

    class_methods do
      def before_attached(attachment_name, method_name = nil, &block)
        register_attachment_callback(:before_attached, attachment_name, method_name, &block)
      end

      def after_attached(attachment_name, method_name = nil, &block)
        register_attachment_callback(:after_attached, attachment_name, method_name, &block)
      end

      def before_detached(attachment_name, method_name = nil, &block)
        register_attachment_callback(:before_detached, attachment_name, method_name, &block)
      end

      def after_detached(attachment_name, method_name = nil, &block)
        register_attachment_callback(:after_detached, attachment_name, method_name, &block)
      end

      private

      def register_attachment_callback(callback_type, attachment_name, method_name = nil, &block)
        raise ArgumentError, "Must provide either a method name or a block" unless method_name || block

        callback = method_name || block
        attachment_name = attachment_name.to_s

        # Deep dup the callbacks hash to avoid mutation issues
        new_callbacks = _attachment_callbacks.deep_dup
        new_callbacks[callback_type][attachment_name] ||= []
        new_callbacks[callback_type][attachment_name] << callback

        self._attachment_callbacks = new_callbacks
      end
    end

    def _run_attachment_callbacks(callback_type, attachment)
      callbacks = self.class._attachment_callbacks[callback_type][attachment.name]
      return unless callbacks

      callbacks.each do |cb|
        invoke_callback(cb, attachment)
      end
    rescue StandardError => e
      Rails.logger.error("#{callback_type} callback failed on #{self.class}##{attachment.name}: #{e.message}")
      raise
    end

    # Convenience methods for backward compatibility and clarity
    def _run_before_attached_callbacks(attachment)
      _run_attachment_callbacks(:before_attached, attachment)
    end

    def _run_after_attached_callbacks(attachment)
      _run_attachment_callbacks(:after_attached, attachment)
    end

    def _run_before_detached_callbacks(attachment)
      _run_attachment_callbacks(:before_detached, attachment)
    end

    def _run_after_detached_callbacks(attachment)
      _run_attachment_callbacks(:after_detached, attachment)
    end

    def invoke_callback(callback, attachment)
      case callback
      when Symbol, String
        send(callback, attachment)
      else
        instance_exec(attachment, &callback)
      end
    end
  end
end
