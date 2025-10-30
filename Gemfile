# frozen_string_literal: true

source "https://rubygems.org"

git_source(:github) { |repo| "https://github.com/#{repo}" }

gem 'ostruct'
branch = ENV.fetch("BRANCH", "main")
gem "activesupport"
gem "activemodel"
gem "activejob"

gem "minitest-bisect"
gem "minitest-reporters"

gemspec

platform :mri do
  group :test do
    gem "ruby-prof"
  end
end

group :test do
  gem 'debug'
  gem 'pry'
  gem 'pry-stack_explorer'
  gem 'rails', "~> 8.1"
  gem 'trilogy'
end
