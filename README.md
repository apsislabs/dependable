# Dependable

[![Build Status](https://travis-ci.org/apsislabs/dependable.svg?branch=master)](https://travis-ci.org/apsislabs/dependable)
[![Coverage Status](https://coveralls.io/repos/github/apsislabs/dependable/badge.svg?branch=master)](https://coveralls.io/github/apsislabs/dependable?branch=master)

Dependable is a small gem for tracking dependency relationships

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'dependable'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install dependable

## Usage

Simply include Dependable on any class that you want to enforce dependency constraints on.

```ruby
class MyService
    include Dependable

    # do lots of cool stuff.
end
```

A class that is Dependable, can only call another Dependable class if it explicitly lists the other class in its dependencies.

```ruby
class NetworkService < MyService  # NetworkService is now Dependable, as it inherits from MyService, which is Dependable
    def self.get(url)
        # omitted
    end
end

class StripeService < MyService # BAD
    def self.get_customer
        ...
        NetworkService.get(url) # this will explode, because we didn't list our dependency explicitly
    end
end

class StripeService < MyService # GOOD
    dependencies NetworkService

    def self.get_customer
        ...
        NetworkService.get(url) # this will run as expected
    end
end
```

## Remaining Work

Currently dependable is only tracks dependency relations between classes. Future work may include tracking dependency relationships between object instances.

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/apsislabs/dependable. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).
