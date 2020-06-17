class ParticipantsRoom < ApplicationRecord
  belongs_to :users, class_name: "User", foreign_key: :user_id
  belongs_to :rooms, class_name: "Room", foreign_key: :room_id
  belongs_to :participants, class_name: "Participant", foreign_key: :participant_id

  validates :user_id, presence: true
  validates :room_id, presence: true
  validates :participant_id, presence: true

  def self.remove_participant(user_id, room_id, participant_id)

    ParticipantsRoom.find_by(
      room_id: room_id, 
      participant_id: participant_id
    ).update_attributes(
      enabled: "inactive by #{user_id}", 
      updated_at: DateTime.now
    )

  end

end