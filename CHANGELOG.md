## [Unreleased]

## [0.1.0] - 2025-07-31

### Added
- Initial release of after_attached gem
- Complete set of attachment lifecycle callbacks:
  - `before_attached` - runs before an attachment is saved
  - `after_attached` - runs after an attachment is committed to the database
  - `before_detached` - runs before an attachment is destroyed
  - `after_detached` - runs after an attachment is destroyed and committed
- Support for method symbols and blocks as callbacks
- Support for multiple callbacks per attachment
- Support for both `has_one_attached` and `has_many_attached` associations
- Automatic inclusion in all Active Record models via Railtie
- Guards to prevent duplicate callback execution
- Full test coverage with RSpec
- CI/CD setup with GitHub Actions testing against Rails 6.1, 7.0, 7.1, and 8.0
