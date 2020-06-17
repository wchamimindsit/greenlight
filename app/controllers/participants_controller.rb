class ParticipantsController < ApplicationController
  def show
    @search2 = "search2"
    @order_column2 = "order_column2"
    @order_direction2 = "order_direction2"
    logger.info "ParticipantsController index"
  end

  # POST /:room_uid/destroy
  def destroy
    begin
    rescue => exception
    end
  end

  # POST /:room_uid/update
  def def(update)
    begin
    rescue => exception
    end
  end

  # DELETE /:room_uid/delete_participant
  def delete_participant
    begin
      
      room_id = Room.find_by(uid: params[:room_uid]).id
      participant_id = params[:remove]
      user_id = session[:user_id]

      logger.info "delete_participant -> room_id: #{room_id}, participant_id: #{participant_id}"

      ParticipantsRoom.remove_participant(user_id, room_id, participant_id)
        
      flash[:success] = I18n.t("participant.remove_participant_success")

    rescue => e
      logger.error "Support: Error in delete_participant: #{e}"
      flash[:alert] = I18n.t("participant.remove_participant_error")
    end

    # Redirects to the page that made the initial request
    redirect_back fallback_location: room_path
  end
  
  # POST /:room_uid/create
  def create
    begin
      columns_db = t("columns_participant_create")
      validator = columns_db.slice(0, 3)
      data = params[:add]
      ncolumns_file = data.values[0].length

      if (validator & data.keys) == validator #validar los campos minimos requeridos
        lstInsert = {}
        arrIdentification = []
        #variables para validacion de los partipantes por sala
        room_id = Room.find_by(uid: params[:room_uid]).id
        user_id = session[:user_id]

        ncolumns_file.times do |i| #array con la cantidad de datos de la primera fila
          lstInsert[i] = []
        end

        nfield = 0
        #transponer los datos del objeto creado en la lectura del archivo
        columns_db.each do |field|
          j = 0
          if data[field].nil?
            ncolumns_file.times do |i|
              case nfield
              when 6 #field PIN
                lstInsert[i].push(lstInsert[i][1]) #push the value of identification
              else #another field empty
                lstInsert[i].push("") #
              end
            end
          else
            data[field].each do |value| #recorrer los datos en el orden del insert
              case nfield
              when 0 #identification_type
                lstInsert[j].push(value.downcase)
              when 6 #field PIN
                if (value == "")
                  lstInsert[j].push(lstInsert[j][1])
                else
                  lstInsert[j].push(value)
                end
              else
                lstInsert[j].push(value)
              end

              j += 1
            end
          end
          nfield += 1
        end #end for columns_db

        j = 0
        arrValidate = []
        #verificar si algun participante se repite dentro del archivo
        #con el mismo tipo de identificacion e identificacion
        lstInsert.each do |index, row|
          if (arrValidate.select { |v| v["id"] == "#{row[0]}_#{row[1]}" } == [])
            arrValidate.push({ "index" => j, "id" => row[0] + "_" + row[1], "repeated" => false })
          else
            arrValidate.push({ "index" => j, "id" => row[0] + "_" + row[1], "repeated" => true })
          end
          j += 1
        end

        #eliminar los participantes con tipo de identificacion e identificacion repetidos
        #dentro del mismo archivo
        arrValidate.select { |v| v["repeated"] == true }.each do |obj| #recorrer los indices de datos repetidos para eliminarlos
          lstInsert.delete(obj["index"])
        end

        #insert
        lstInsert.each do |index, row|

          #consultar el participante por identification_type y identification
          objParticipant = Participant.where(identification_type: row[0], identification: row[1]).first
          #consultar el participante filtrado por room_id
          objParticipantXRoom = Participant.from_room(room_id).where(identification_type: row[0], identification: row[1]).first
          #objeto para guardar el objeto del partipante recien creado
          objCreateParticipant = nil

          begin
            #si no existe en la tabla Participant
            if objParticipant.nil?
              #Guardar en la tabla Participant
              objCreateParticipant =
                Participant.create(
                  identification_type: row[0],
                  identification: row[1],
                  name: row[2],
                  surnames: row[3],
                  email: row[4],
                  address: row[5],
                  pin: row[6],
                  phone: row[7],
                  gender: row[8],
                )
            end

            #Si el participante no existe en la sala
            if objParticipantXRoom.nil?
              #si el partipante es nuevo
              unless objCreateParticipant.nil?
                ParticipantsRoom.create(
                  user_id: user_id,
                  room_id: room_id,
                  participant_id: objCreateParticipant.id,
                )
              else #si el partipante ya existia en la tabla Participant
                ParticipantsRoom.create(
                  user_id: user_id,
                  room_id: room_id,
                  participant_id: objParticipant.id,
                )
              end
            end
          rescue => exception
            logger.error "Support: Error in file upload participants: #{exception}"
          end
        end
        #end insert

        flash[:success] = I18n.t("participant.save_participants_success")
      else
        logger.error "Support: The file doesn't contain the required columns"
        flash[:alert] = I18n.t("participant.save_participants_error")
      end
    rescue => e
      logger.error "Support: Error in file upload participants: #{e}"
      flash[:alert] = I18n.t("participant.save_participants_error")
    end

    redirect_back fallback_location: room_path
  end

  #
end