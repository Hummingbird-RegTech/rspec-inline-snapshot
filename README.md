# rspec-inline-snapshot
Inline snapshot matchers for RSpec. Inspired by [Jest](https://jestjs.io/), [rspec-snapshot](https://github.com/levinmr/rspec-snapshot), and others!

Open-sourced in 2022 by Hummingbird RegTech, Inc.

## Installation
Add this line to your application's Gemfile:

```ruby
gem 'rspec-inline-snapshot'
```

And then execute:

    $ bundle install

Or install it yourself as:

    $ gem install rspec-inline-snapshot

## Usage
The gem provides the `match_inline_snapshot` RSpec matcher. This matcher will self-modify the spec file with the
expected value.

If the matcher is not provided with an argument, the code will update the snapshot by editing the spec file on first run.
This can also be a useful workflow for updating a single snapshot... simply remove the argument and re-run the test.
```ruby
expect(what_the_cat_said).to match_inline_snapshot

# ... will result in the code self-modifying ... and the test passes

expect(what_the_cat_said).to match_inline_snapshot('meow')
```

If an expected value is passed to the matcher, the behavior depends on whether the `UPDATE_SNAPSHOTS`
environment variable is set. If it is set, the snapshot is updated (surprise!). If it is not, the test will fail.

```ruby
# ... without UPDATE_SNAPSHOTS=true set ... 
expect(what_the_cat_said).to match_inline_snapshot('woof') # boom!

# ... with UPDATE_SNAPSHOTS=true set ...
expect(what_the_cat_said).to match_inline_snapshot('woof')
# ... will result in the code self-modifying ... and the test passes
expect(what_the_cat_said).to match_inline_snapshot('meow')
```

The snapshotting works with many kinds of objects. In the event of a multi-line string, it will generate a heredoc
to enhance readability.
```ruby
expect(JSON.pretty_generate(some_hash)).to match_inline_snapshot(<<~SNAP.chomp)
  {
    "a": 1,
    "b": 2,
    "c": {
      "d": 3,
      "e": 4
    }
  }
SNAP

expect(number_of_cats).to match_inline_snapshot(123)

expect(what_the_cat_said).to match_inline_snapshot('meow')
```

For legacy reasons, the `UPDATE_MATCH_SNAPSHOT` and `UPDATE_SNAPSHOTS` environment variables are equivalent and
can be used interchangeably.

### In CI
Most CI providers set the `CI` environment variable. `rspec-inline-snapshot` will detect this
and "do the right thing" in this situation... it will refuse to update snapshots.

## Contributing
Just send a bug report or pull request on Github!

Our lawyers would like you to know that if you do send a pull request, you are agreeing to license
your code under the same license as the rest of the repo, the Apache 2.0 license.
