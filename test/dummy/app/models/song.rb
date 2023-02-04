class Song < ApplicationRecord
  belongs_to :singer, polymorphic: true
end
