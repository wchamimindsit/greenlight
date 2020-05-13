class Organization < ApplicationRecord

  has_many :users  

  before_save { email.try(:downcase!) }
  validates :name, length: { maximum: 256 }, presence: true
  validates :email, length: { maximum: 256 }, allow_blank: true,
  uniqueness: { case_sensitive: false, scope: :provider },
  format: { with: /\A[\w+\-.]+@[a-z\d\-.]+\.[a-z]+\z/i }

end