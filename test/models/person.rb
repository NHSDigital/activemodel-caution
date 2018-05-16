class Person
  include ActiveModel::Cautions

  attr_accessor :tel
  attr_accessor :age
  attr_accessor :height_in_inches
  attr_accessor :mood
  attr_accessor :name
  attr_accessor :likes_scooby_snacks

  caution :warn_against_short_tel_number

  cautions :height_in_inches,
    :numericality => { :only_integer => true, :allow_nil => true },
    :inclusion    => { :in => 1..100, :allow_nil => true, :message => "is a ridiculous height" }

  cautions_numericality_of :age, :allow_nil => true

  cautions :mood, inclusion: { in: %w(doom) , value: ->(p) { p.mood.try(:reverse) }, allow_nil: true }

  cautions :likes_scooby_snacks, presence: true, if: :in_scooby_gang?
  caution :warn_against_scooby_snack_intolerance, if: -> { in_scooby_gang? && name != 'Shaggy' }

  def in_scooby_gang?
    name.in? %w[Shaggy Fred Velma Daphne]
  end

  def warn_against_short_tel_number
    warnings.add(:base, 'Contact number is less than 11 digits') if tel && tel.length < 11
  end

  def warn_against_scooby_snack_intolerance
    warnings.add(:likes_scooby_snacks, 'Only Shaggy likes Scooby Snacks') if likes_scooby_snacks
  end
end
