class Participant < ApplicationRecord

    has_many :users  
  
    before_save { email.try(:downcase!) }
    
    validates :identification, presence: true
    validates :identification_type, presence: true
    validates :name, length: { maximum: 256 }, presence: true
  
  end