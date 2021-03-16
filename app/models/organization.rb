class Organization < ApplicationRecord

  has_many :users  
  has_many :rooms, through: :users

  before_save { email.try(:downcase!) }
  validates :name, length: { maximum: 256 }, presence: true
  validates :email, length: { maximum: 256 }, allow_blank: true,
  uniqueness: { case_sensitive: false },
  format: { with: /\A[\w+\-.]+@[a-z\d\-.]+\.[a-z]+\z/i , message: "Email invalid" }

  def self.find_by_id(id)
    Organization.where(id: id).select(:name, :address, :phone, :email, :email_verified, :maxusers, :nextinvoice, :enabled, :updated_at_user).first
  end

  def count_users
    User.select(:id).where(organization: self.id).count
  end

  def self.duplicate_name(name)
    Organization.exists?(name: name)
  end

  def self.duplicate_id_and_name(id, name)
    Organization.where.not(id: id).exists?(name: name)
  end

  # Save a new organization
  def self.create_new_organization(user_id, organization)
    begin
      
    #updated_at: DateTime.now
    #logger.info [].join
    new_organization = Organization.create(
      name: organization[:name],
      address: organization[:address],
      phone: organization[:phone],
      email: organization[:email],
      email_verified: organization[:email_verified],
      maxusers: organization[:maxusers],
      nextinvoice: Time.find_zone("Bogota").parse(organization[:nextinvoice]),
      updated_at_user: user_id,
      enabled: true
    )
    
    new_organization.save!
    new_organization

    rescue => exception
      logger.error "Failed to save a new organization: #{exception}"
      return nil
    end
  end

  # Update a organization
  def self.update_the_organization(user_id, organization_id, organization)
    begin
      
    #updated_at: DateTime.now
    update_organization = Organization.find_by(id: organization_id);

    return nil if update_organization.nil?

    update_organization.update(
      name: organization[:name],
      address: organization[:address],
      phone: organization[:phone],
      email: organization[:email],
      email_verified: organization[:email_verified],
      maxusers: organization[:maxusers],
      nextinvoice: Time.find_zone("Bogota").parse(organization[:nextinvoice]),
      updated_at_user: user_id
    )
    
    update_organization.save!
    update_organization

    rescue => exception
      logger.error "Failed to update a organization: #{exception}"
      return nil
    end
  end

  # Update a organization
  def self.update_status_organization(user_id, organization_id, status)
    begin
      
    update_organization = Organization.find_by(id: organization_id);

    return nil if update_organization.nil?

    disable_users_by_organization(organization_id) if !status

    update_organization.update_attributes(enabled: status)
    update_organization

    rescue => exception
      logger.error "Failed to disable a organization: #{exception}"
      return nil
    end
  end

  #Disable Users By Organization
  def self.disable_users_by_organization(organization_id)
    #Select active users and delete them
    User.where(organization: organization_id).update_all(deleted: true)
  end

  #Update Users By Organization
  def self.update_users_by_organization(users, organization_id)
    begin

      lstUsers = User.where(id: users);

      lstUsers.each do |user| 
        user.update_attributes(organization_id: organization_id)
      end

      return lstUsers.length
      
    rescue => exception
      logger.error "Failed to update the users by organization: #{exception}"
      return nil
    end
    
  end

end