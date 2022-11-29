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
      Money.new(send("#{name}_cents"), send("#{name}_currency"))
    end
  end
end
