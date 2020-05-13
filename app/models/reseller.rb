class Reseller < ApplicationRecord

  has_many :organization

  before_save { email.try(:downcase!) }
  validates :email, length: { maximum: 256 }, allow_blank: true,
  uniqueness: { case_sensitive: false, scope: :provider },
  format: { with: /\A[\w+\-.]+@[a-z\d\-.]+\.[a-z]+\z/i }

end