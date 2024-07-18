require 'active_resource/act_as_active_record'

module Client
  class Musician < ActiveResource::Base
    self.site = "http://bloc.kr"

    include ActiveResource::ActAsActiveRecord
  end

  class Composer < Musician
    
  end
end
