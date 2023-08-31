require 'money'
require 'active_resource/schema'

ActiveResource::Schema.set_custom_attribute_type(
  ActiveResource::AttributeConfig.new(:money) do |resource, repo_name, attr_name, value|
    resource.send(repo_name)[attr_name.to_s] = Money.new(value['cents'], value['currency'])
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
      string currency_attr, skip_duplicate_accessor: true
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
