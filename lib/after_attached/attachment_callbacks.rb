# frozen_string_literal: true

module AfterAttached
  module AttachmentCallbacks
    extend ActiveSupport::Concern

    included do
      class_attribute :_attachment_callbacks, default: {}
    end

    class_methods do
      def after_attached(attachment_name, method_name = nil, &block)
        raise ArgumentError, "Must provide either a method name or a block" unless method_name || block

        callback = method_name || block
        self._attachment_callbacks = _attachment_callbacks.merge(
          attachment_name.to_s => _attachment_callbacks[attachment_name.to_s].to_a + [callback]
        )
      end
    end

    def _run_after_attached_callbacks(attachment)
      self.class._attachment_callbacks[attachment.name]&.each do |cb|
        invoke_callback(cb, attachment)
      end
    rescue StandardError => e
      Rails.logger.error("after_attached callback failed on #{self.class}##{attachment.name}: #{e.message}")
      raise
    end

    private

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
