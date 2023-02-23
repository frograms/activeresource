class Animal < ActiveResource::Base
  self._headers = {kingdom: 'animal'}
end

class Mammal < Animal
  self._headers = {phylum: 'mammal'}
end

class Dog < Mammal
  self._headers = {phylum: 'mammal2', class: 'dog'}
end
