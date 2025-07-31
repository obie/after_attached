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
        MultiCallbackDocument._attachment_callbacks = {}

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

    describe "error handling" do
      it "raises ArgumentError when neither method nor block is provided" do
        expect do
          document_class.after_attached :file
        end.to raise_error(ArgumentError, "Must provide either a method name or a block")
      end
    end
  end
end
