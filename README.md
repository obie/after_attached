# AfterAttached

Provides `after_attached` callbacks for Rails models with Active Storage attachments. This allows you to run code exactly once whenever a blob is first attached or later replaced.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'after_attached'
```

And then execute:

    $ bundle install

## Usage

The gem automatically includes the `AttachmentCallbacks` concern in all Active Record models, so you can use `after_attached` directly:

```ruby
class User < ApplicationRecord
  has_one_attached :avatar
  
  # Using a method
  after_attached :avatar, :process_avatar
  
  private
  
  def process_avatar(attachment)
    # This will run once when avatar is attached
    AvatarProcessingJob.perform_later(self, attachment)
  end
end
```

You can also use a block:

```ruby
class Document < ApplicationRecord
  has_one_attached :file
  
  after_attached :file do |attachment|
    # Access attachment properties
    Rails.logger.info "Attached file: #{attachment.filename}"
    Rails.logger.info "Content type: #{attachment.content_type}"
    Rails.logger.info "File size: #{attachment.byte_size}"
  end
end
```

### Multiple Callbacks

You can define multiple callbacks for the same attachment:

```ruby
class Photo < ApplicationRecord
  has_one_attached :image
  
  after_attached :image, :generate_thumbnail
  after_attached :image, :extract_metadata
  after_attached :image do |attachment|
    notify_admin("New photo uploaded: #{attachment.filename}")
  end
end
```

### Works with has_many_attached

The callbacks fire for each attachment when using `has_many_attached`:

```ruby
class Gallery < ApplicationRecord
  has_many_attached :photos
  
  after_attached :photos do |attachment|
    # This runs for each photo attached
    ProcessPhotoJob.perform_later(attachment)
  end
end

# Attaching multiple files
gallery.photos.attach([photo1, photo2]) # Callback fires twice, once for each photo

# Adding more photos later
gallery.photos.attach(photo3) # Callback fires once for the new photo
```

### Replacing Attachments

The callbacks fire once when replacing a `has_one_attached` attachment:

```ruby
user.avatar.attach(first_file)  # Callbacks fire
user.avatar.attach(second_file) # Callbacks fire again for the new attachment
```

## How It Works

Under the hood, the gem:
1. Includes an `AttachmentCallbacks` concern in all Active Record models via a Rails initializer
2. Patches `ActiveStorage::Attachment.after_create_commit` to trigger the callbacks
3. Maintains a registry of callbacks per model using a `class_attribute`

No blob ID tracking or complex bookkeeping - just simple, reliable callbacks that fire once per attachment. Since the callbacks are triggered at the `ActiveStorage::Attachment` level, they work seamlessly with both `has_one_attached` and `has_many_attached` associations.

## Compatibility

- Rails 6.0+
- Ruby 3.0+

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/obiefernandez/after_attached. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/obiefernandez/after_attached/blob/main/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the AfterAttached project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/obiefernandez/after_attached/blob/main/CODE_OF_CONDUCT.md).