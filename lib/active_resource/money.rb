require 'money'

ActiveResource::Base.instance_eval do
  def monetize(name, currency_attr: nil, amount_attr: nil)
    currency_attr ||= "#{name}_currency"
    amount_attr ||= "#{name}_cents"
    schema do
      string currency_attr
      integer amount_attr
    end
    define_method(name) do
      Money.new(send(amount_attr), send(currency_attr))
    end
    define_method(:"#{name}=") do |money|
      send(:"#{currency_attr}=", money.currency.iso_code)
      send(:"#{amount_attr}=", money.cents)
    end
  end
end
