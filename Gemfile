# frozen_string_literal: true

source 'https://rubygems.org'

gemspec

gem 'logger'
gem 'mysql2', '~> 0.5.0',  :platform => :ruby
# pg 0.18.4 (the historical pin) no longer builds on Ruby 3.x / modern libpq;
# 1.5+ is required for the suite to install on contemporary toolchains.
gem 'pg',     '~> 1.5',    :platform => :ruby

# The HTTP bulk feature calls searchd.http=, which only exists in the craftybase
# riddle fork; the gemspec's `riddle ~> 2.4` otherwise resolves upstream riddle
# (which lacks it), so the suite can't boot. Pinned to the same ref craftybase-app
# uses. See CU-868k5c7jn.
gem 'riddle', github: 'craftybase/riddle', ref: '001c1a8'

gem 'activerecord', '< 7' if RUBY_VERSION.to_f <= 2.4

if RUBY_PLATFORM == 'java'
  gem 'jdbc-mysql',                          '5.1.35',    :platform => :jruby
  gem 'activerecord-jdbcmysql-adapter',      '>= 1.3.23', :platform => :jruby
  gem 'activerecord-jdbcpostgresql-adapter', '>= 1.3.23', :platform => :jruby
  gem 'activerecord', '>= 3.2.22'
end
