class TalkingPetError < StandardError; end

class Pet < ActiveRecord::Base

  attr_accessor :greeting, :name

  before_cautions :learn_to_speak

  caution :warn_against_mute_pet
  caution :warn_against_unborn_pet
  caution :warn_against_check_out_pet

  cautions_presence_of :greeting
  cautions_format_of :name, without: /[0-9]/, message: "can't contain numbers"

  after_cautions :freak_out_if_pet_can_talk

  def warn_against_unborn_pet
    warnings.add(:birthdate, "Birth date is in the future") if birthdate && birthdate > Date.today
  end

  def warn_against_check_out_pet
    warnings.add(:status, "Pet is checking out", :active => true) if status && status == 'out'
  end

  def warn_against_mute_pet
    warnings.add(:greeting, "Pet is too quiet") if greeting.blank?
  end

  def learn_to_speak
    self.greeting ||= 'Woof'
  end

  def freak_out_if_pet_can_talk
    raise(TalkingPetError) if greeting == "Hello there, friend!"
  end
end
