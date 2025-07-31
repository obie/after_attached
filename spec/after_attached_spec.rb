# frozen_string_literal: true

require "spec_helper"
require "tempfile"

RSpec.describe AfterAttached do
  it "has a version number" do
    expect(AfterAttached::VERSION).not_to be nil
  end

  describe "AttachmentCallbacks" do
    # Define test model before each test
    before do
      # Remove existing class definition if it exists
      Object.send(:remove_const, :TestDocument) if defined?(TestDocument)

      # Define the test class
      class TestDocument < ActiveRecord::Base
        self.table_name = "documents"

        has_one_attached :file
        has_one_attached :image

        attr_accessor :file_processed, :image_processed, :attachment_info

        after_attached :file, :process_file
        after_attached :image do |attachment|
          self.image_processed = true
          self.attachment_info = {
            filename: attachment.filename.to_s,
            content_type: attachment.content_type
          }
        end

        private

        def process_file(_attachment)
          self.file_processed = true
        end
      end
    end

    let(:document_class) { TestDocument }

    let(:document) { document_class.create!(name: "Test Document") }
    let(:file) { Tempfile.new(["test", ".txt"]) }
    let(:image) { Tempfile.new(["test", ".jpg"]) }

    before do
      file.write("test content")
      file.rewind

      image.write("fake image data")
      image.rewind
    end

    after do
      file.close
      file.unlink

      image.close
      image.unlink
    end

    describe "after_attached with method symbol" do
      it "calls the specified method when attachment is created" do
        expect(document.file_processed).to be_nil

        document.file.attach(
          io: file,
          filename: "test.txt",
          content_type: "text/plain"
        )

        expect(document.file_processed).to be true
      end

      it "does not call callback for other attachments" do
        document.image.attach(
          io: image,
          filename: "test.jpg",
          content_type: "image/jpeg"
        )

        expect(document.file_processed).to be_nil
      end
    end

    describe "after_attached with block" do
      it "executes the block when attachment is created" do
        expect(document.image_processed).to be_nil
        expect(document.attachment_info).to be_nil

        document.image.attach(
          io: image,
          filename: "test.jpg",
          content_type: "image/jpeg"
        )

        expect(document.image_processed).to be true
        expect(document.attachment_info).to eq({
                                                 filename: "test.jpg",
                                                 content_type: "image/jpeg"
                                               })
      end
    end

    describe "replacing attachments" do
      it "triggers callback when replacing has_one_attached" do
        # First attachment
        document.file.attach(
          io: file,
          filename: "first.txt",
          content_type: "text/plain"
        )

        document.file_processed = nil

        # Replace attachment
        new_file = Tempfile.new(["new", ".txt"])
        new_file.write("new content")
        new_file.rewind

        document.file.attach(
          io: new_file,
          filename: "second.txt",
          content_type: "text/plain"
        )

        expect(document.file_processed).to be true

        new_file.close
        new_file.unlink
      end
    end

    describe "multiple callbacks" do
      it "supports multiple callbacks for the same attachment" do
        # Create a new class to avoid pollution from the main test class
        Object.send(:remove_const, :MultiCallbackDocument) if defined?(MultiCallbackDocument)

        callback_order = []

        class MultiCallbackDocument < ActiveRecord::Base
          self.table_name = "documents"
          has_one_attached :file
        end

        # Reset callbacks to ensure clean state
        MultiCallbackDocument._attachment_callbacks = {
          before_attached: {},
          after_attached: {},
          before_detached: {},
          after_detached: {}
        }

        attachment_ids = []

        MultiCallbackDocument.after_attached :file do |attachment|
          attachment_ids << attachment.id
          callback_order << :first
        end

        MultiCallbackDocument.after_attached :file do |attachment|
          attachment_ids << attachment.id
          callback_order << :second
        end

        doc = MultiCallbackDocument.create!(name: "Multi callback test")

        # Track attachment creations
        attachment_count = ActiveStorage::Attachment.count

        doc.file.attach(
          io: file,
          filename: "test.txt",
          content_type: "text/plain"
        )

        # Check only one attachment was created
        expect(ActiveStorage::Attachment.count - attachment_count).to eq(1)

        # Check that we only ran callbacks once
        expect(attachment_ids.uniq.size).to eq(1)
        expect(callback_order).to eq(%i[first second])
      end
    end

    describe "has_many_attached" do
      before do
        Object.send(:remove_const, :Gallery) if defined?(Gallery)

        class Gallery < ActiveRecord::Base
          self.table_name = "documents"
          has_many_attached :photos

          attr_accessor :photos_processed

          after_attached :photos do |attachment|
            @photos_processed ||= []
            @photos_processed << attachment.filename.to_s
          end
        end
      end

      let(:gallery) { Gallery.create!(name: "Test Gallery") }

      it "triggers callback for each attachment in has_many_attached" do
        photo1 = Tempfile.new(["photo1", ".jpg"])
        photo2 = Tempfile.new(["photo2", ".jpg"])

        photo1.write("photo1 data")
        photo2.write("photo2 data")
        photo1.rewind
        photo2.rewind

        gallery.photos.attach([
                                { io: photo1, filename: "photo1.jpg", content_type: "image/jpeg" },
                                { io: photo2, filename: "photo2.jpg", content_type: "image/jpeg" }
                              ])

        expect(gallery.photos_processed).to contain_exactly("photo1.jpg", "photo2.jpg")

        photo1.close
        photo1.unlink
        photo2.close
        photo2.unlink
      end

      it "triggers callback when adding more attachments" do
        photo1 = Tempfile.new(["photo1", ".jpg"])
        photo1.write("photo1 data")
        photo1.rewind

        gallery.photos.attach(io: photo1, filename: "photo1.jpg", content_type: "image/jpeg")
        expect(gallery.photos_processed).to eq(["photo1.jpg"])

        photo2 = Tempfile.new(["photo2", ".jpg"])
        photo2.write("photo2 data")
        photo2.rewind

        gallery.photos.attach(io: photo2, filename: "photo2.jpg", content_type: "image/jpeg")
        expect(gallery.photos_processed).to eq(["photo1.jpg", "photo2.jpg"])

        photo1.close
        photo1.unlink
        photo2.close
        photo2.unlink
      end
    end

    describe "before_attached callbacks" do
      before do
        Object.send(:remove_const, :BeforeAttachedDocument) if defined?(BeforeAttachedDocument)

        class BeforeAttachedDocument < ActiveRecord::Base
          self.table_name = "documents"
          has_one_attached :file

          attr_accessor :before_called, :after_called, :callback_order

          before_attached :file do |_attachment|
            self.before_called = true
            self.callback_order ||= []
            self.callback_order << :before
          end

          after_attached :file do |_attachment|
            self.after_called = true
            self.callback_order ||= []
            self.callback_order << :after
          end
        end
      end

      it "executes before_attached before the attachment is saved" do
        doc = BeforeAttachedDocument.create!(name: "Test")

        doc.file.attach(
          io: file,
          filename: "test.txt",
          content_type: "text/plain"
        )

        expect(doc.before_called).to be true
        expect(doc.after_called).to be true
        expect(doc.callback_order).to eq(%i[before after])
      end
    end

    describe "detachment callbacks" do
      before do
        Object.send(:remove_const, :DetachmentDocument) if defined?(DetachmentDocument)

        class DetachmentDocument < ActiveRecord::Base
          self.table_name = "documents"
          has_one_attached :file

          attr_accessor :before_detached_called, :after_detached_called, :detach_order,
                        :attachment_info_on_before_detach, :attachment_info_on_after_detach

          before_detached :file do |attachment|
            self.before_detached_called = true
            self.detach_order ||= []
            self.detach_order << :before
            self.attachment_info_on_before_detach = {
              filename: attachment.filename.to_s,
              attached: file.attached?
            }
          end

          after_detached :file do |attachment|
            self.after_detached_called = true
            self.detach_order ||= []
            self.detach_order << :after
            self.attachment_info_on_after_detach = {
              filename: attachment.filename.to_s,
              # Can't reliably check attached? in after_detached as association might be cached
              destroyed: attachment.destroyed?
            }
          end
        end
      end

      it "executes detachment callbacks when attachment is removed" do
        doc = DetachmentDocument.create!(name: "Test")

        # Attach a file
        doc.file.attach(
          io: file,
          filename: "test.txt",
          content_type: "text/plain"
        )

        # Clear attachment state
        doc.before_detached_called = nil
        doc.after_detached_called = nil

        # Detach the file by destroying the attachment
        # Note: purge bypasses destroy callbacks, so we destroy the attachment directly
        doc.file.attachment.destroy!

        expect(doc.before_detached_called).to be true
        expect(doc.after_detached_called).to be true
        expect(doc.detach_order).to eq(%i[before after])

        # Before detach, the attachment should still be accessible
        expect(doc.attachment_info_on_before_detach[:filename]).to eq("test.txt")
        expect(doc.attachment_info_on_before_detach[:attached]).to be true

        # After detach, the attachment is destroyed
        expect(doc.attachment_info_on_after_detach[:filename]).to eq("test.txt")
        expect(doc.attachment_info_on_after_detach[:destroyed]).to be true
      end

      it "triggers callbacks when replacing an attachment" do
        doc = DetachmentDocument.create!(name: "Test")

        # Attach first file
        doc.file.attach(
          io: file,
          filename: "first.txt",
          content_type: "text/plain"
        )

        # Clear state
        doc.before_detached_called = nil
        doc.after_detached_called = nil
        doc.detach_order = nil

        # Replace with new file
        new_file = Tempfile.new(["new", ".txt"])
        new_file.write("new content")
        new_file.rewind

        doc.file.attach(
          io: new_file,
          filename: "second.txt",
          content_type: "text/plain"
        )

        # Callbacks should have fired for the detachment of the first file
        expect(doc.before_detached_called).to be true
        expect(doc.after_detached_called).to be true
        expect(doc.detach_order).to eq(%i[before after])
        expect(doc.attachment_info_on_before_detach[:filename]).to eq("first.txt")

        new_file.close
        new_file.unlink
      end
    end

    describe "has_many_attached with all callbacks" do
      before do
        Object.send(:remove_const, :FullCallbackGallery) if defined?(FullCallbackGallery)

        class FullCallbackGallery < ActiveRecord::Base
          self.table_name = "documents"
          has_many_attached :photos

          attr_accessor :callback_log

          before_attached :photos do |attachment|
            @callback_log ||= []
            @callback_log << { type: :before_attached, filename: attachment.filename.to_s }
          end

          after_attached :photos do |attachment|
            @callback_log ||= []
            @callback_log << { type: :after_attached, filename: attachment.filename.to_s }
          end

          before_detached :photos do |attachment|
            @callback_log ||= []
            @callback_log << { type: :before_detached, filename: attachment.filename.to_s }
          end

          after_detached :photos do |attachment|
            @callback_log ||= []
            @callback_log << { type: :after_detached, filename: attachment.filename.to_s }
          end
        end
      end

      it "triggers all callbacks for has_many_attached" do
        gallery = FullCallbackGallery.create!(name: "Test Gallery")

        photo1 = Tempfile.new(["photo1", ".jpg"])
        photo1.write("photo1 data")
        photo1.rewind

        # Attach photo
        gallery.photos.attach(io: photo1, filename: "photo1.jpg", content_type: "image/jpeg")

        # Check attachment callbacks
        expect(gallery.callback_log).to include(
          { type: :before_attached, filename: "photo1.jpg" },
          { type: :after_attached, filename: "photo1.jpg" }
        )

        # Clear log
        gallery.callback_log = []

        # Remove photo
        gallery.photos.first.destroy!

        # Check detachment callbacks
        expect(gallery.callback_log).to include(
          { type: :before_detached, filename: "photo1.jpg" },
          { type: :after_detached, filename: "photo1.jpg" }
        )

        photo1.close
        photo1.unlink
      end
    end

    describe "error handling" do
      it "raises ArgumentError when neither method nor block is provided" do
        expect do
          document_class.after_attached :file
        end.to raise_error(ArgumentError, "Must provide either a method name or a block")
      end

      it "raises ArgumentError for all callback types without method or block" do
        expect { document_class.before_attached :file }.to raise_error(ArgumentError)
        expect { document_class.before_detached :file }.to raise_error(ArgumentError)
        expect { document_class.after_detached :file }.to raise_error(ArgumentError)
      end
    end
  end
end
