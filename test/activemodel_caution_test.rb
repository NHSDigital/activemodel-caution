require 'test_helper'
require 'models/person'
require 'models/pet'

class ActivemodelCautionTest < ActiveSupport::TestCase
  test "active model with base warnings" do
    person = Person.new
    assert_equal true, person.safe?
    person.tel = '12345'
    assert_equal false, person.safe?
    assert_equal 1, person.warnings.size
    assert_equal 1, person.warnings.count
    assert_equal ["Contact number is less than 11 digits"], person.warnings[:base]
    assert_equal({}, person.warnings.active)
  end

  test "active model with helper_method-generated warnings" do
    person = Person.new
    assert_equal true, person.safe?

    person.age = 'very old'
    assert_equal false, person.safe?
    assert_equal 1, person.warnings.size
    assert_equal 1, person.warnings.count
    assert_equal ["is not a number"], person.warnings[:age]
    assert_equal({}, person.warnings.active)

    person.age = 23
    assert_equal true, person.safe?
  end

  test "active model with attributes warnings" do
    person = Person.new

    person.height_in_inches = 12.1
    assert_equal false, person.safe?
    assert_equal 1, person.warnings.size
    assert_equal 1, person.warnings.count
    assert_equal ["must be an integer"], person.warnings[:height_in_inches]
    assert_equal({}, person.warnings.active)

    person.height_in_inches = 500
    assert_equal false, person.safe?
    assert_equal 1, person.warnings.size
    assert_equal 1, person.warnings.count
    assert_equal ["is a ridiculous height"], person.warnings[:height_in_inches]
    assert_equal({}, person.warnings.active)

    person.height_in_inches = 12
    assert_equal true, person.safe?
  end

  test 'active model with conditional warnigns' do
    person = Person.new

    person.safe?
    assert_empty person.warnings[:likes_scooby_snacks]

    person.name = 'Velma'
    person.likes_scooby_snacks = true
    person.safe?
    refute_empty person.warnings[:likes_scooby_snacks]

    person.name = 'Shaggy'
    person.likes_scooby_snacks = nil
    person.safe?
    refute_empty person.warnings[:likes_scooby_snacks]

    person.likes_scooby_snacks = true
    person.safe?
    assert_empty person.warnings[:likes_scooby_snacks]
  end

  test "pet runs cautions callbacks" do
    pet = Pet.new
    assert_nil pet.greeting
    pet.safe? # before callback should teach pet to speak
    assert !pet.warnings[:greeting].include?("Pet is too quiet")
    assert !pet.greeting.nil?

    pet.greeting = 'Hello there, friend!'
    assert_raises(TalkingPetError) { pet.safe? }
  end

  test "safe pet without any warnings" do
    pet = Pet.create(
      :name => 'Baileys',
      :category => 'Dog',
      :birthdate => '2011-11-03',
      :description => 'Warren',
      :status => 'in'
    )

    assert_equal 'Baileys', pet.name
    assert_equal true, pet.safe?
    assert_equal false, pet.unsafe?
  end

  test "pet with presence caution" do
    pet = Pet.new(:greeting => '') # Explicitly set to prevent callback

    pet.safe?
    assert pet.warnings[:greeting].include?("can't be blank")

    pet.greeting = 'woof woof!'

    pet.safe?
    assert pet.warnings[:greeting].exclude?("can't be blank")
  end

  test "pet with format caution" do
    pet = Pet.new(name: 'K9')

    pet.safe?
    assert pet.warnings[:name].include?("can't contain numbers")

    pet.name = 'Kay Nine'
    pet.safe?
    refute pet.warnings[:name].include?("can't contain numbers")
  end

  test "pet with standard inactive warnings" do
    pet = Pet.create(:name => 'Ben', :birthdate => Date.today.next_month)
    assert_equal false, pet.safe?
    assert_equal false, pet.warnings.empty?
    assert_equal 1, pet.warnings.size
    assert_equal 1, pet.warnings.count
    assert_equal ["Birth date is in the future"], pet.warnings[:birthdate]
    assert_equal ["Birth date is in the future"], pet.warnings['birthdate']
    assert_equal({:birthdate => ["Birth date is in the future"]}, pet.warnings.messages)
    assert_equal({}, pet.warnings.active)
  end

  test "pet with active warnings" do
    pet = Pet.create(:name => 'Ben', :status => 'out')
    assert_equal false, pet.safe?
    assert_equal({:status => ["Pet is checking out"]}, pet.warnings.messages)
    assert_equal({:status => ["Pet is checking out"]}, pet.warnings.active)
    assert_equal 1, pet.warnings.size

    pet.warnings.add(:status, "Pet is still out", :active => true)
    assert_equal({:status =>["Pet is checking out", "Pet is still out"]}, pet.warnings.messages)
    assert_equal({:status =>["Pet is checking out", "Pet is still out"]}, pet.warnings.active)
    assert_equal 2, pet.warnings.size
  end

  test "pet with both active and inactive warnings" do
    pet = Pet.create(:name => 'Ben', :birthdate => Date.today.next_month, :status => 'out')
    assert_equal false, pet.safe?
    assert_equal({:status =>["Pet is checking out"]}, pet.warnings.active)
    assert_equal({:birthdate =>["Birth date is in the future"], :status =>["Pet is checking out"]}, pet.warnings.messages)
    assert_equal 2, pet.warnings.size

    assert_difference "pet.warnings.size", +1 do
      pet.warnings.add(:status, "Pet is still out", :active => true)
    end
  end

  test "active warnings should raise a validation error" do
    pet = Pet.create(:name => 'Ben', :birthdate => Date.today.next_month, :status => 'out')
    assert pet.unsafe?
    assert pet.warnings.active.any?

    # Unconfirmed warning should raise error:
    assert pet.invalid?
    assert pet.errors[:base].include?("The following warnings need confirmation: Status Pet is checking out")
    assert ! pet.errors[:base].include?("is in the future") # Passive warnings should not be listed
    assert pet.warnings_need_confirmation?
  end

  test "active warnings should not raise validation error once confirmed" do
    pet = Pet.create(:name => 'Ben', :status => 'out')
    assert pet.unsafe?
    assert pet.warnings.active.any?

    # Unconfirmed warning should raise error:
    assert pet.invalid?
    assert pet.errors[:base].any?
    assert pet.warnings_need_confirmation?

    # Get position confirmation:
    assert ! pet.confirmed_safe?
    pet.active_warnings_confirm_decision = true
    assert ! pet.warnings_need_confirmation?
    assert pet.confirmed_safe?

    assert pet.unsafe? # Should not change
    assert pet.valid?  # But validation should pass
  end

  test "active warnings should still be invalid without confirm" do
    pet = Pet.create(:name => 'Ben', :status => 'out')
    assert pet.unsafe?
    assert pet.warnings.active.any?

    # Unconfirmed warning should raise error:
    assert pet.invalid?
    assert pet.errors[:base].any?
    assert pet.warnings_need_confirmation?

    # Get negative confirmation from user:
    assert ! pet.confirmed_safe?
    pet.active_warnings_confirm_decision = false
    assert ! pet.warnings_need_confirmation?
    assert ! pet.confirmed_safe?

    assert pet.unsafe?  # Should not change
    assert pet.invalid? # Should still be invalid
  end

  test 'active warnings should not be raised as validations when avoiding them' do
    pet = Pet.new(name: 'Ben', birthdate: Date.today.next_month, status: 'out')
    assert pet.unsafe?
    assert pet.warnings.active.any?

    assert pet.valid_ignoring_unconfirmed_active_warnings?
    refute pet.errors[:base].any?
    refute pet.warnings_need_confirmation?
  end

  test "active_messages should print full messages" do
    pet = Pet.create(:name => 'Ben', :birthdate => Date.today.next_month, :status => 'out')
    pet.safe?

    assert_equal ["Status Pet is checking out"], pet.warnings.active_messages
    assert_equal ["Birthdate Birth date is in the future", "Status Pet is checking out"], pet.warnings.full_messages
  end

  test "passive method" do
    pet = Pet.create(:name => 'Ben', :birthdate => Date.today.next_month, :status => 'out')
    assert pet.unsafe?

    assert_equal({:status =>["Pet is checking out"]}, pet.warnings.active)
    assert_equal({:birthdate =>["Birth date is in the future"]}, pet.warnings.passive)
    assert_equal({:birthdate =>["Birth date is in the future"], :status =>["Pet is checking out"]}, pet.warnings.messages)
  end

  test "passive method after active access" do
    pet = Pet.create(:name => 'Ben', :birthdate => Date.today.next_month, :status => 'out')
    assert pet.unsafe?

    assert_empty pet.warnings.active[:birthdate]

    assert_equal({:birthdate =>["Birth date is in the future"]}, pet.warnings.passive)
    assert_equal({:birthdate =>["Birth date is in the future"], :status =>["Pet is checking out"]}, pet.warnings.messages)
  end

  test "clear all warnings" do
    pet = Pet.create(:name => 'Ben', :birthdate => Date.today.next_month, :status => 'out')
    assert_equal false, pet.safe?

    pet.warnings.clear
    assert_equal 0, pet.warnings.size
    assert_equal({}, pet.warnings.messages)
    assert_equal({}, pet.warnings.active)
    assert_equal true, pet.warnings.empty?
  end

  test 'using custom value for warning' do
    person = Person.new

    person.mood = 'null'
    refute person.safe?
    assert_equal(['is not included in the list'], person.warnings[:mood])

    person.mood = 'mood'
    person.safe?
    assert person.warnings[:mood].blank?
  end
end
