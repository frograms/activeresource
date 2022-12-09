require 'money'
require 'active_resource/schema'

ActiveResource::Schema.set_custom_attribute_type(
  ActiveResource::Schema::TypeConfig.new(:money) do |attributes, key, value|
    attributes[key.to_s] = Money.new(value['cents'], value['currency'])
  end
)

class Money
  def resource_json(options = nil)
    {'cents' => cents, 'currency' => currency.iso_code.to_s}
  end
end

ActiveResource::Base.instance_eval do
  def monetize(name, currency_attr: nil, cents_attr: nil)
    currency_attr ||= "#{name}_currency"
    cents_attr ||= "#{name}_cents"

    schema do
      string currency_attr
      integer cents_attr
    end

    define_method(name) do
      Money.new(send(cents_attr), send(currency_attr))
    end

    define_method(:"#{name}=") do |money|
      send(:"#{currency_attr}=", money.currency.iso_code)
      send(:"#{cents_attr}=", money.cents)
    end
  end
end
