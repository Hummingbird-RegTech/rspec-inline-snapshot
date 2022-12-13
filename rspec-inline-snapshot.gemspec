require File.expand_path('lib/rspec/inline_snapshot/version', __dir__)

Gem::Specification.new do |s|
  s.name                  = 'rspec-inline-snapshot'
  s.version               = RSpec::InlineSnapshot::VERSION
  s.homepage              = 'https://github.com/Hummingbird-RegTech/rspec-inline-snapshot'
  s.summary               = 'Inline snapshot expectations for RSpec'
  s.description           = 'Inline snapshot expectations for RSpec'
  s.authors               = ['Hummingbird RegTech, Inc.']
  s.email                 = 'info@hummingbird.co'
  s.files                 = Dir.glob('lib/**/*')
  s.license               = 'Apache-2.0'

  s.required_ruby_version = '>= 2.7.0'

  s.add_dependency 'rspec'
  s.add_dependency 'rubocop'
  s.add_dependency 'rubocop-ast'
  s.add_development_dependency 'rspec'
  s.metadata['rubygems_mfa_required'] = 'true'
end
