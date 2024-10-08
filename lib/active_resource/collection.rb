# frozen_string_literal: true

require "active_support/core_ext/module/delegation"
require "active_support/inflector"

module ActiveResource # :nodoc:
  class Collection # :nodoc:
    SELF_DEFINE_METHODS = [:to_a, :collect!, :map!, :all?]
    include Enumerable
    delegate :to_yaml, :all?, *(Array.instance_methods(false) - SELF_DEFINE_METHODS), to: :to_a

    # The array of actual elements returned by index actions
    attr_accessor :elements, :resource_class, :original_params, :after_collect

    # ActiveResource::Collection is a wrapper to handle parsing index responses that
    # do not directly map to Rails conventions.
    #
    # You can define a custom class that inherits from ActiveResource::Collection
    # in order to to set the elements instance.
    #
    # GET /posts.json delivers following response body:
    #   {
    #     posts: [
    #       {
    #         title: "ActiveResource now has associations",
    #         body: "Lorem Ipsum"
    #       },
    #       {...}
    #     ],
    #     next_page: "/posts.json?page=2"
    #   }
    #
    # A Post class can be setup to handle it with:
    #
    #   class Post < ActiveResource::Base
    #     self.site = "http://example.com"
    #     self.collection_parser = PostCollection
    #   end
    #
    # And the collection parser:
    #
    #   class PostCollection < ActiveResource::Collection
    #     attr_accessor :next_page
    #     def initialize(parsed = {})
    #       @elements = parsed['posts']
    #       @next_page = parsed['next_page']
    #     end
    #   end
    #
    # The result from a find method that returns multiple entries will now be a
    # PostParser instance.  ActiveResource::Collection includes Enumerable and
    # instances can be iterated over just like an array.
    #    @posts = Post.find(:all) # => PostCollection:xxx
    #    @posts.next_page         # => "/posts.json?page=2"
    #    @posts.map(&:id)         # =>[1, 3, 5 ...]
    #
    # The initialize method will receive the ActiveResource::Formats parsed result
    # and should set @elements.
    def initialize(elements = [])
      @elements = elements
    end

    def to_a
      elements
    end

    def collect_cache
      @collect_cache ||= {}
    end

    def collect!
      return elements unless block_given?
      set = []
      each { |o| set << yield(o) }
      @elements = set
      collect_cache.each_pair do |attr_config, cache|
        attr_config.run_after_collect(cache)
      end
      self
    end
    alias map! collect!

    def first_or_create(attributes = {})
      first || resource_class.create(original_params.update(attributes))
    rescue NoMethodError
      raise "Cannot create resource from resource type: #{resource_class.inspect}"
    end

    def first_or_initialize(attributes = {})
      first || resource_class.new(original_params.update(attributes))
    rescue NoMethodError
      raise "Cannot build resource from resource type: #{resource_class.inspect}"
    end

    def where(clauses = {})
      raise ArgumentError, "expected a clauses Hash, got #{clauses.inspect}" unless clauses.is_a? Hash
      new_clauses = original_params.merge(clauses)
      resource_class.where(new_clauses)
    end
  end
end
