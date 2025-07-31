# frozen_string_literal: true

module ActiveStorageHelpers
  def create_file_blob(filename: "test.txt", content_type: "text/plain", content: "test content")
    ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new(content),
      filename: filename,
      content_type: content_type
    )
  end
end
