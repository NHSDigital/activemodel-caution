# Warnings for ActiveModel [![Build Status](https://travis-ci.org/PublicHealthEngland/activemodel-caution.svg?branch=master)](https://travis-ci.org/PublicHealthEngland/activemodel-caution)

The activemodel-caution gem mirrors ActiveModel's validation framework to provide non-blocking warnings.
It is possible to specify a warning as 'active', in which case it must be confirmed (otherwise a
validation error is raised).

The codebase is heavily based on the ActiveModel's Validation framework.

## Installation

### With Bundler

Add this line to your application's Gemfile:

```ruby
gem 'activemodel-caution', :git => 'https://github.com/PublicHealthEngland/activemodel-caution.git'
```

And then execute:

    $ bundle

### From Source

Or install it yourself by cloning the project, then executing:

    $ gem build activemodel-caution.gemspec
    $ gem install ./activemodel-caution-1.0.3.gem

## Usage

## Basic

Basic usage is similar to ActiveModel's validations:

```ruby
class Post < ActiveRecord::Base
  caution :warn_against_empty_content

  private

  def warn_against_empty_content
    warnings.add(:content, 'is blank') if content.blank?
  end
end

@post = Post.new(title: 'My first blog', content: '')
@post.valid?  #=> true
@post.safe?   #=> false
@post.unsafe? #=> true
@post.warnings.messages #=> { :content => ['Content is blank'] }
```

### Active Warnings

Also included are "active warnings", which trigger a validation error until they are confirmed:

```ruby
class Post < ActiveRecord::Base
  caution :actively_warn_against_empty_content

  private

  def actively_warn_against_empty_content
    warnings.add(:content, 'is blank', active: true) if content.blank?
  end
end

@post = Post.new(title: 'My first blog', content: '')
@post.valid?  #=> false
@post.safe?   #=> false
@post.unsafe? #=> true
@post.warnings.active #=> { :content => ['Content is blank'] }
@post.errors[:base]   #=> 'The following warnings need confirmation: Content is blank'
```

The object must then be "confirmed as safe" to be valid:

```ruby
@post.warnings_need_confirmation? #=> true
@post.confirmed_safe? #=> false

@post.active_warnings_confirm_decision = true

# We no longer are waiting for a decision...
@post.warnings_need_confirmation? #=> false
# ...and the decision was, in this case, positive:
@post.confirmed_safe? #=> true

@post.valid?  #=> true
@post.safe?   #=> false
```

## Development

### Synchronising updates

This repository aims to mirror the validations of `ActiveModel` / `ActiveRecord` in both functionality and implementation.
As such, releases are tagged to mirror Rails' own. The file `version.rb` defines both `RAILS_VERSION` and `GEM_VERSION` -
the latter of which can be use to release intermediate updates should they be necessary.

Changes needing mirroring can be found with e.g. the below, although it's wise to review the full changelogs in detail too.

```
rails$ git diff v6.0.0.rc1..v6.0.0.rc2 --stat -- {activemodel/lib/active_model,activerecord/lib/active_record}/{error,validat}*
```

### Contributing

1. Fork it ( https://github.com/PublicHealthEngland/activemodel-caution/fork )
2. Create your feature branch (git checkout -b my-new-feature)
3. Commit your changes (git commit -am 'Add some feature')
4. Push to the branch (git push origin my-new-feature)
5. Create a new Pull Request

Please note that this project is released with a Contributor Code of Conduct. By participating in this project you agree to abide by its terms.

### Testing

Development dependencies can be installed using bundler in the usual way.
Tests can be run with

    $ bundle exec rake

They currently use an in-memory SQLite database when testing the ActiveRecord integration.
