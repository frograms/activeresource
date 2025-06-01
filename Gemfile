# frozen_string_literal: true

source "https://rubygems.org"

git_source(:github) { |repo| "https://github.com/#{repo}" }

branch = ENV.fetch("BRANCH", "main")
gem "activesupport"
gem "activemodel"
gem "activejob"

gem "rubocop"
gem "rubocop-minitest"
gem "rubocop-packaging"
gem "rubocop-performance"
gem "rubocop-rails"

gem "minitest-bisect"
gem "minitest-reporters"

gemspec

platform :mri do
  group :test do
    gem "ruby-prof"
  end
end

group :test do
  gem 'pry'
  gem 'pry-byebug'
  gem 'pry-stack_explorer'
  gem 'mocha'
  gem 'rails', "~> 8.0"
  gem 'mysql2'
end
