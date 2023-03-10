class Animal < ActiveResource::Base
  self._headers = {kingdom: 'animal'}
end

class Mammal < Animal
  self._headers = {phylum: 'mammal'}

  def self.headers_base
    h = super
    h.update(class: 'unknown')
    h
  end
end

class Dog < Mammal
  self._headers = {phylum: 'mammal2', class: 'dog'}
end
