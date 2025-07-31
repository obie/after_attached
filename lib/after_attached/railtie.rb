# frozen_string_literal: true

module AfterAttached
  class Railtie < Rails::Railtie
    initializer "after_attached.setup_callbacks" do
      ActiveSupport.on_load(:active_record) do
        include AfterAttached::AttachmentCallbacks
      end

      ActiveSupport.on_load(:active_storage_attachment) do
        after_create_commit do
          record = self.record

          # Guard against multiple calls
          @_after_attached_run ||= false
          unless @_after_attached_run
            @_after_attached_run = true
            if record.class.respond_to?(:_attachment_callbacks) && record.respond_to?(:_run_after_attached_callbacks)
              record._run_after_attached_callbacks(self)
            end
          end
        end
      end
    end
  end
end
