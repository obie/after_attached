# AfterAttached

Provides comprehensive attachment lifecycle callbacks for Rails models with Active Storage attachments. Run code before and after attachments are created or destroyed.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'after_attached'
```

And then execute:

    $ bundle install

## Usage

The gem automatically includes the `AttachmentCallbacks` concern in all Active Record models, providing four callbacks for attachment lifecycle events:

- `before_attached` - runs before an attachment is saved
- `after_attached` - runs after an attachment is committed to the database
- `before_detached` - runs before an attachment is destroyed
- `after_detached` - runs after an attachment is destroyed and committed

### Basic Usage

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

### All Available Callbacks

```ruby
class Document < ApplicationRecord
  has_one_attached :file

  # Called before the attachment record is created
  before_attached :file do |attachment|
    Rails.logger.info "About to attach: #{attachment.filename}"
  end

  # Called after the attachment record is committed
  after_attached :file do |attachment|
    ProcessingJob.perform_later(attachment)
  end

  # Called before the attachment record is destroyed
  before_detached :file do |attachment|
    Rails.logger.info "About to detach: #{attachment.filename}"
  end

  # Called after the attachment record is destroyed and committed
  after_detached :file do |attachment|
    CleanupJob.perform_later(record_id: id, filename: attachment.filename.to_s)
  end
end
```

### Replacing Attachments

When replacing a `has_one_attached` attachment, both detachment callbacks (for the old attachment) and attachment callbacks (for the new one) fire:

```ruby
user.avatar.attach(first_file)  # before_attached, after_attached fire
user.avatar.attach(second_file) # before_detached, after_detached fire for first_file
                                # then before_attached, after_attached fire for second_file
```

### Removing Attachments

To trigger detachment callbacks, you need to destroy the attachment record:

```ruby
# This triggers before_detached and after_detached callbacks
document.file.attachment.destroy!

# Note: purge and purge_later bypass the destroy callbacks
# If you need the callbacks to fire, use destroy! instead
```

## How It Works

Under the hood, the gem:
1. Includes an `AttachmentCallbacks` concern in all Active Record models via a Rails initializer
2. Patches ActiveStorage::Attachment with ActiveRecord callbacks:
   - `before_create` → triggers `before_attached`
   - `after_create_commit` → triggers `after_attached`
   - `before_destroy` → triggers `before_detached`
   - `after_destroy_commit` → triggers `after_detached`
3. Maintains a registry of callbacks per model and attachment name using a `class_attribute`

No blob ID tracking or complex bookkeeping - just simple, reliable callbacks that fire at the appropriate points in the attachment lifecycle. Since the callbacks are triggered at the `ActiveStorage::Attachment` level, they work seamlessly with both `has_one_attached` and `has_many_attached` associations.

## Compatibility

- Rails 6.0+
- Ruby 3.0+

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/obie/after_attached. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/obie/after_attached/blob/main/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the AfterAttached project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/obie/after_attached/blob/main/CODE_OF_CONDUCT.md).