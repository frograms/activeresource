module Client
  class Musician < ActiveResource::Base
    self.site = "http://bloc.kr"
  end

  class Composer < Musician
    
  end
end
