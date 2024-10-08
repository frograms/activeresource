# frozen_string_literal: true

require "active_resource"
require "rails"

module ActiveResource
  class Railtie < Rails::Railtie
    class << self
      def setup(app)
        ActiveResource::Base.logger = app.config.active_resource.logger || Rails.logger
      end
    end

    config.active_resource = ActiveSupport::OrderedOptions.new

    config.after_initialize do |app|
      ActiveResource::Railtie.setup(app)
    end

    initializer "active_resource.set_configs" do |app|
      ActiveSupport.on_load(:active_resource) do
        app.config.active_resource.each do |k, v|
          send "#{k}=", v
        end
      end
    end

    initializer "active_resource.add_active_job_serializer" do |app|
      if app.config.try(:active_job).try(:custom_serializers)
        require "active_resource/active_job_serializer"
        app.config.active_job.custom_serializers << ActiveResource::ActiveJobSerializer
      end
    end
  end
end
