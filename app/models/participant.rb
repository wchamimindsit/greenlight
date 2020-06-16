class Participant < ApplicationRecord
  has_many :participants_rooms, class_name: "ParticipantsRoom"

  before_save { identification_type.try(:downcase!) }
  before_save { email.try(:downcase!) }

  validates :identification, presence: true
  validates :identification_type, presence: true
  validates :name, length: { maximum: 256 }, presence: true

  def self.by_room_with_pager(room_id, max, pag)
    intOffset = (pag - 1) * max
    objRooms = Participant.from_room(room_id)
    total_pags = objRooms.length 

    [objRooms.limit(max).offset(intOffset), total_pags]
  end

  def self.from_room(room_id)
    Participant.participants_room(room_id).order(name: :asc)
  end

  def self.participants_room(room_id)
    Participant.joins("INNER JOIN participants_rooms ON participants_rooms.participant_id = participants.id ").where(
      "participants_rooms.room_id = #{room_id} AND " \
      "participants_rooms.enabled = 'active' "
    ).distinct
  end
  
end