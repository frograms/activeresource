Rails.application.configure do
  config.after_initialize do
    require 'fixtures/musician'
    ActiveResource::ApiTypeNameObjectMap.multi_set(
      'Musician' => 'Client::Musician',
      )
    ActiveResource::ApiTypeNameObjectMap.api_type_name_fallback do |object|
      case object
      when ActiveRecord::Base then object.class.base_class.name
      else object.class.name
      end
    end
    Musician = Client::Musician
  end
end
