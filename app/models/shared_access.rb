# frozen_string_literal: true

class SharedAccess < ApplicationRecord
  
  belongs_to :users, class_name: "User", foreign_key: :user_id
  belongs_to :rooms, class_name: "Room", foreign_key: :room_id
  validates :user_id, presence: true
  validates :room_id, presence: true

  def self.owner_all
    SharedAccess.select("(SELECT r.user_id FROM rooms r WHERE r.id = shared_accesses.room_id ) as owner_id").collect {|sa| sa.owner_id}
  end
  
  def owner
    begin
      if self
        objSharedAccess = SharedAccess.where("shared_accesses.id = #{self.id}").select("(SELECT r.user_id FROM rooms r WHERE r.id = shared_accesses.room_id ) as owner_id").first
        objSharedAccess.nil? ? 0 : objSharedAccess.owner_id
      end     
    rescue => exception
      logger.info "exception: #{exception}"
    end
  end

end