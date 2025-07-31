# frozen_string_literal: true

module AfterAttached
  class Railtie < Rails::Railtie
    initializer "after_attached.setup_callbacks" do
      ActiveSupport.on_load(:active_record) do
        include AfterAttached::AttachmentCallbacks
      end

      ActiveSupport.on_load(:active_storage_attachment) do
        # Before attached - runs before the attachment is saved
        before_create do
          record = self.record
          # Guard against multiple calls
          @_before_attached_run ||= false
          unless @_before_attached_run
            @_before_attached_run = true
            if record && record.class.respond_to?(:_attachment_callbacks) &&
               record.respond_to?(:_run_before_attached_callbacks)
              record._run_before_attached_callbacks(self)
            end
          end
        end

        # After attached - runs after the attachment is committed
        after_create_commit do
          record = self.record

          # Guard against multiple calls
          @_after_attached_run ||= false
          unless @_after_attached_run
            @_after_attached_run = true
            if record && record.class.respond_to?(:_attachment_callbacks) &&
               record.respond_to?(:_run_after_attached_callbacks)
              record._run_after_attached_callbacks(self)
            end
          end
        end

        # Before detached - runs before the attachment is destroyed
        before_destroy do
          record = self.record
          # Guard against multiple calls
          @_before_detached_run ||= false
          unless @_before_detached_run
            @_before_detached_run = true
            if record && record.class.respond_to?(:_attachment_callbacks) &&
               record.respond_to?(:_run_before_detached_callbacks)
              record._run_before_detached_callbacks(self)
            end
          end
        end

        # After detached - runs after the attachment is destroyed and committed
        after_destroy_commit do
          # Need to get the record before destruction
          record = self.record

          # Guard against multiple calls
          @_after_detached_run ||= false
          unless @_after_detached_run
            @_after_detached_run = true
            if record && record.class.respond_to?(:_attachment_callbacks) &&
               record.respond_to?(:_run_after_detached_callbacks)
              record._run_after_detached_callbacks(self)
            end
          end
        end
      end
    end
  end
end
