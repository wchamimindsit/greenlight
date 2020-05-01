class SessionHistory < ApplicationRecord

  belongs_to :main_room, class_name: 'Room', foreign_key: :room_id

  #Retorna el ultimo registro de sala iniciada por usuario
  def self.most_recent_for(user_id, room_id)
    where(user_id: user_id, room_id: room_id).order("start_session DESC").first
  end

end