class Person
  include ActiveModel::Cautions
  
  attr_accessor :tel
  attr_accessor :age
  attr_accessor :height_in_inches
  attr_accessor :mood


  caution :warn_against_short_tel_number

  cautions :height_in_inches,
    :numericality => { :only_integer => true, :allow_nil => true },
    :inclusion    => { :in => 1..100, :allow_nil => true, :message => "is a ridiculous height" }

  cautions_numericality_of :age, :allow_nil => true

  cautions :mood, inclusion: { in: %w(doom) , value: ->(p) { p.mood.try(:reverse) }, allow_nil: true }

  def warn_against_short_tel_number
    warnings.add(:base, 'Contact number is less than 11 digits') if tel && tel.length < 11
  end
end