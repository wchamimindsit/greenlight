module Organizer
    extend ActiveSupport::Concern

    # Creates a new organization
    def create_organization(user_id, new_organization)

      return nil if Organization.duplicate_name(new_organization[:name]) || new_organization[:name].strip.empty?

      Organization.create_new_organization(user_id, new_organization)
    end

    # Update a organization
    def update_organization_by_id(user_id, organization_id, update_organization)

      return nil if Organization.duplicate_id_and_name(organization_id, update_organization[:name]) || update_organization[:name].strip.empty?

      Organization.update_the_organization(user_id, organization_id, update_organization)
    end

    # Delete a organization
    def delete_organization_by_id(user_id, organization_id)

      Organization.update_status_organization(user_id, organization_id, false)
    end

    # Active a organization
    def active_organization_by_id(user_id, organization_id)

      Organization.update_status_organization(user_id, organization_id, true)
    end

    # Returns a list of organizations that are in the same context of the search string
    def organization_list

      organizations_case = case @tab
        when "active"
          Organization.where(enabled: true).where("lower(name) like ?", "%#{@search.downcase}%")
        when "deleted"
          Organization.where(enabled: false).where("lower(name) like ?", "%#{@search.downcase}%")
      end
      
      organizations_case
    end

end