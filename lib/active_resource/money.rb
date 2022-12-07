require 'money'

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
