# frozen_string_literal: true

# BigBlueButton open source conferencing system - http://www.bigbluebutton.org/.
#
# Copyright (c) 2018 BigBlueButton Inc. and by respective authors (see below).
#
# This program is free software; you can redistribute it and/or modify it under the
# terms of the GNU Lesser General Public License as published by the Free Software
# Foundation; either version 3.0 of the License, or (at your option) any later
# version.
#
# BigBlueButton is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
# PARTICULAR PURPOSE. See the GNU Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public License along
# with BigBlueButton; if not, see <http://www.gnu.org/licenses/>.

class RoomsController < ApplicationController
  include Pagy::Backend
  include Recorder
  include Joiner
  include Populator

  before_action :validate_accepted_terms, unless: -> { !Rails.configuration.terms }
  before_action :validate_verified_email, except: [:show, :join],
                unless: -> { !Rails.configuration.enable_email_verification }
  before_action :find_room, except: [:create, :join_specific_room]
  before_action :verify_room_ownership_or_admin_or_shared, only: [:start, :shared_access]
  before_action :verify_room_ownership_or_admin, only: [:update_settings, :destroy]
  before_action :verify_room_ownership_or_shared, only: [:remove_shared_access]
  before_action :verify_room_owner_verified, only: [:show, :join],
                unless: -> { !Rails.configuration.enable_email_verification }
  before_action :verify_room_owner_valid, only: [:show, :join]
  before_action :verify_user_not_admin, only: [:show]

  # POST /
  def create
    # Return to root if user is not signed in
    return redirect_to root_path unless current_user

    # Check if the user has not exceeded the room limit
    return redirect_to current_user.main_room, flash: { alert: I18n.t("room.room_limit") } if room_limit_exceeded

    # Create room
    @room = Room.new(name: room_params[:name], access_code: room_params[:access_code])
    @room.owner = current_user
    @room.room_settings = create_room_settings_string(room_params)

    # Save the room and redirect if it fails
    return redirect_to current_user.main_room, flash: { alert: I18n.t("room.create_room_error") } unless @room.save

    logger.info "Support: #{current_user.email} has created a new room #{@room.uid}."

    # Redirect to room is auto join was not turned on
    return redirect_to @room,
      flash: { success: I18n.t("room.create_room_success") } unless room_params[:auto_join] == "1"

    # Start the room if auto join was turned on
    start
  end

  # GET /:room_uid/load_manage_participant
  def load_manage_participant

    begin
    @room = Room.find_by(uid: params[:room_uid])
    @participants = Participant.from_room(@room.id)

    if current_user && current_user.organization_id
      session[:organization] = current_user.organization_id
    else
      session[:organization] = User.find_by(id: @room.user_id).organization_id
    end
      
    rescue => e
      logger.error "Error on load manage participant: #{e}"
    end
    
  end

  #GET /:room_uid/show_recordings
  def show_recordings
    begin

      #load recordings
      show_room_recordings
      #reder the partial view
      render partial: 'shared/sessions', locals: { recordings: @public_recordings, pagy: @pagy, only_public: true, user_recordings: false, title: t("room.recordings") }, formats: :html, layout: false
      
    rescue => e
      logger.error "Error on show_recordings: #{e}"
    end
  end

  # GET /:room_uid
  def show

    load_manage_participant if current_user

    @anyone_can_start = JSON.parse(@room[:room_settings])["anyoneCanStart"]
    @room_running = room_running?(@room.bbb_id)
    @shared_room = room_shared_with_user

    if current_user && current_user.organization_id
      @organization = Organization.find_by(id: current_user.organization_id)
    end    

    # If its the current user's room
    if current_user && (@room.owned_by?(current_user) || @shared_room)
      if current_user.highest_priority_role.get_permission("can_create_rooms")
        # User is allowed to have rooms
        @search, @order_column, @order_direction, recs =
          recordings(@room.bbb_id, params.permit(:search, :column, :direction), true)

        @user_list = shared_user_list if shared_access_allowed

        @pagy, @recordings = pagy_array(recs)
      else
        # Render view for users that cant create rooms
        @recent_rooms = Room.where(id: cookies.encrypted["#{current_user.uid}_recently_joined_rooms"])
        render :cant_create_rooms
      end
    else
      return redirect_to root_path, flash: { alert: I18n.t("room.invalid_provider") } if incorrect_user_domain

      show_user_join
    end

    if !@organization.nil? 
      
      if @organization.nextinvoice && @organization.reseller_id && @organization.reseller_id == 1 && DateTime.now() > @organization.nextinvoice

        expiration_date = @organization.nextinvoice
        expiration_date = (expiration_date + (Rails.configuration.grace_days_for_use.to_i * 86400)).to_s

        if DateTime.now() > expiration_date
          logger.info "La organizacion #{@organization.name} ha caducado y ha pasado los dias de gracia: #{expiration_date}"
          flash[:alert] = I18n.t("aulaparatodos_exception_expiration_grace_day")
        else
          logger.info "La organizacion #{@organization.name} ha caducado: #{@organization.nextinvoice}"
          flash[:alert] = I18n.t("aulaparatodos_exception_expiration")
        end 
        
      end
    end

  end

  # POST /:room_uid
  def join
    return redirect_to root_path,
      flash: { alert: I18n.t("administrator.site_settings.authentication.user-info") } if auth_required

    @shared_room = room_shared_with_user

    unless @room.owned_by?(current_user) || @shared_room
      # Don't allow users to join unless they have a valid access code or the room doesn't have an access code
      if @room.access_code && !@room.access_code.empty? && @room.access_code != session[:access_code]
        return redirect_to room_path(room_uid: params[:room_uid]), flash: { alert: I18n.t("room.access_code_required") }
      end

      # Assign join name if passed.
      if params[@room.invite_path]
        @join_name = params[@room.invite_path][:join_name]
      elsif !params[:join_name]
        # Join name not passed.
        return redirect_to root_path
      end
    end

    # create or update cookie with join name
    cookies.encrypted[:greenlight_name] = @join_name unless cookies.encrypted[:greenlight_name] == @join_name

    save_recent_rooms

    logger.info "Support: #{current_user.present? ? current_user.email : @join_name} is joining room #{@room.uid}"
    join_room(default_meeting_options)
  end

  # DELETE /:room_uid
  def destroy
    begin
      # Don't delete the users home room.
      raise I18n.t("room.delete.home_room") if @room == @room.owner.main_room
      @room.destroy
      #Inactiva los usuarios de la sala, pero no los borra
      ParticipantsRoom.remove_room(current_user.id, @room.id)
    rescue => e
      flash[:alert] = I18n.t("room.delete.fail", error: e)
    else
      flash[:success] = I18n.t("room.delete.success")
    end

    # Redirect to home room if the redirect_back location is the deleted room
    return redirect_to @current_user.main_room if request.referer == room_url(@room)

    # Redirect to the location that the user deleted the room from
    redirect_back fallback_location: current_user.main_room
  end

  # POST /room/join
  def join_specific_room
    room_uid = params[:join_room][:url].split('/').last

    begin
      @room = Room.find_by!(uid: room_uid)
    rescue ActiveRecord::RecordNotFound
      return redirect_to current_user.main_room, alert: I18n.t("room.no_room.invalid_room_uid")
    end

    redirect_to room_path(@room)
  end

  # POST /:room_uid/start
  def start
    logger.info "Support: #{current_user.email} is starting room #{@room.uid}"

    # Validaciones en caso de que no este autorizado a iniciar conferencias por vencimiento de licencia
    if current_user && current_user.organization_id
      @organization = Organization.find_by(id: current_user.organization_id)

      if !@organization.nil? 
        if @organization.nextinvoice && @organization.reseller_id && @organization.reseller_id == 1
          
          expiration_date = @organization.nextinvoice
          expiration_date = (expiration_date + (Rails.configuration.grace_days_for_use.to_i * 86400)).to_s

          if DateTime.now() > expiration_date
            return redirect_to current_user.main_room, flash: { alert: I18n.t("aulaparatodos_exception_expiration_grace_day") }
          end
          
        end
      end
    end  
    # Fin validaciones

    active_rooms = 0
    active_room_name = ""
    current_user.ordered_rooms_active.each do |room|

      running = room_running?(room.bbb_id)
      if running
        meeting = get_meeting(room.bbb_id, room.moderator_pw)

        if meeting[:participantCount] == 0
          room.update_attributes(end_last_session: DateTime.now, active: false)
          end_meeting(room.bbb_id, room.moderator_pw)
          logger.info "Finalizando sala activa: #{room.id} | #{room.uid} | Participantes activos: #{meeting[:participantCount]}"
        else
          logger.info "Sala activa: #{room.id} | #{room.uid} | Participantes activos: #{meeting[:participantCount]}"
          active_room_name = room.name
          if @room.id != room.id
            active_rooms += 1
          end  
        end
      else
        if @room.id != room.id
          room.update_attributes(end_last_session: DateTime.now, active: false)
        end        
      end   
       
    end

    if active_rooms > 0
      logger.info("Support: #{@room.uid} not start")
      redirect_to room_path, alert: I18n.t("bigbluebutton_exception_active_room", room_name: active_room_name)
    else
      # Join the user in and start the meeting.
      opts = default_meeting_options
      opts[:user_is_moderator] = true

      # Include the user's choices for the room settings
      room_settings = JSON.parse(@room[:room_settings])
      opts[:mute_on_start] = room_settings["muteOnStart"]
      opts[:require_moderator_approval] = room_settings["requireModeratorApproval"]

      begin
        redirect_to join_path(@room, current_user.name, opts, current_user.uid)
      rescue BigBlueButton::BigBlueButtonException => e
        logger.error("Support: #{@room.uid} start failed: #{e}")

        redirect_to room_path, alert: I18n.t(e.key.to_s.underscore, default: I18n.t("bigbluebutton_exception"))
      end

      # Notify users that the room has started.
      # Delay 5 seconds to allow for server start, although the request will retry until it succeeds.
      NotifyUserWaitingJob.set(wait: 5.seconds).perform_later(@room)
    end
  end

  # POST /:room_uid/update_settings
  def update_settings
    begin
      options = params[:room].nil? ? params : params[:room]
      raise "Room name can't be blank" if options[:name].blank?

      # Update the rooms values
      room_settings_string = create_room_settings_string(options)

      @room.update_attributes(
        name: options[:name],
        room_settings: room_settings_string,
        access_code: options[:access_code]
      )

      flash[:success] = I18n.t("room.update_settings_success")
    rescue => e
      logger.error "Support: Error in updating room settings: #{e}"
      flash[:alert] = I18n.t("room.update_settings_error")
    end

    redirect_back fallback_location: room_path(@room)
  end

  # POST /:room_uid/update_shared_access
  def shared_access
    begin
      current_list = @room.shared_users.pluck(:id)
      new_list = User.where(uid: params[:add]).pluck(:id)

      # Get the list of users that used to be in the list but were removed
      users_to_remove = current_list - new_list
      # Get the list of users that are in the new list but not in the current list
      users_to_add = new_list - current_list

      # Remove users that are removed
      SharedAccess.where(room_id: @room.id, user_id: users_to_remove).delete_all unless users_to_remove.empty?

      # Add users that are added
      users_to_add.each do |id|
        SharedAccess.create(room_id: @room.id, user_id: id)
      end

      flash[:success] = I18n.t("room.shared_access_success")
    rescue => e
      logger.error "Support: Error in updating room shared access: #{e}"
      flash[:alert] = I18n.t("room.shared_access_error")
    end

    redirect_back fallback_location: room_path
  end

  # POST /:room_uid/remove_shared_access
  def remove_shared_access
    begin
      SharedAccess.find_by!(room_id: @room.id, user_id: params[:user_id]).destroy
      flash[:success] = I18n.t("room.remove_shared_access_success")
    rescue => e
      logger.error "Support: Error in removing room shared access: #{e}"
      flash[:alert] = I18n.t("room.remove_shared_access_error")
    end

    redirect_to current_user.main_room
  end

  # GET /:room_uid/shared_users
  def shared_users
    # Respond with JSON object of users that have access to the room
    respond_to do |format|
      format.json { render body: @room.shared_users.to_json }
    end
  end

  # GET /:room_uid/room_settings
  def room_settings
    # Respond with JSON object of the room_settings
    respond_to do |format|
      format.json { render body: @room.room_settings.to_json }
    end
  end

  # GET /:room_uid/logout
  def logout
    logger.info "Support: #{current_user.present? ? current_user.email : 'Guest'} has left room #{@room.uid}"

    if current_user.present? ? @room.owned_by?(current_user) : false
      if room_running?(@room.bbb_id)
        logger.info "Esta saliendo el dueño de la sala"
      else
        logger.info "Esta finalizando sesion el dueño de la sala"
        @room.update_attributes(end_last_session: DateTime.now, active: false)

        @session_history = SessionHistory.most_recent_for(current_user.id, @room.id)
        @session_history.update_attributes(end_session: DateTime.now)
      end     
    end

    # Redirect the correct page.
    redirect_to @room
  end

  # def logout
  #   logger.info "Support: #{current_user.present? ? current_user.email : 'Guest'} has left room #{@room.uid}"

  #   if current_user.present? ? @room.owned_by?(current_user) : false
  #     role_user_room = @room.user_by_owned&.highest_priority_role.name
  #     if room_running_by_role?(@room.bbb_id, role_user_room)
  #       logger.info "Esta saliendo el dueño de la sala"
  #     else
  #       logger.info "Esta finalizando sesion el dueño de la sala"
  #       @room.update_attributes(end_last_session: DateTime.now, active: false)

  #       @session_history = SessionHistory.most_recent_for(current_user.id, @room.id)
  #       @session_history.update_attributes(end_session: DateTime.now)
  #     end     
  #   end

  #   # Redirect the correct page.
  #   redirect_to @room
  # end

  # POST /:room_uid/login
  def login
    session[:access_code] = room_params[:access_code]

    flash[:alert] = I18n.t("room.access_code_required") if session[:access_code] != @room.access_code

    redirect_to room_path(@room.uid)
  end

  private

  def create_room_settings_string(options)
    room_settings = {
      "muteOnStart": options[:mute_on_join] == "1",
      "requireModeratorApproval": options[:require_moderator_approval] == "1",
      "anyoneCanStart": options[:anyone_can_start] == "1",
      "joinModerator": options[:all_join_moderator] == "1",
      "privateRoom": options[:private_room] == "1",
    }

    room_settings.to_json
  end

  def room_params
    params.require(:room).permit(:name, :auto_join, :mute_on_join, :access_code,
      :require_moderator_approval, :anyone_can_start, :all_join_moderator, :private_room)
  end

  # Find the room from the uid.
  def find_room

    data_parameters = params[:room_uid]
    parameters = data_parameters.split('&')

    if parameters.length > 1
      begin

        data_uid = parameters[0]
        data_parameters = Room.decode_params(parameters[1])
        parameters = data_parameters.split('&')
        
        data_user = parameters[0]
        data_pin = parameters[1]

        params[:room_uid] = data_uid
        params[:user_name] = data_user
        params[:user_pin] = data_pin

        cookies.encrypted[:room_uid] = data_uid
        cookies.encrypted[:user_name] = data_user
        cookies.encrypted[:user_pin] = data_pin

        logger.info "Accediendo desde evaluateok: #{data_user} [#{data_pin}]"
      rescue => e
        logger.error "Error on find room: #{e}"
        # Fallo y puedo hacer esta accion
        if cookies.encrypted[:room_uid] && cookies.encrypted[:room_uid] == params[:room_uid]
          params[:user_name] = cookies.encrypted[:user_name]
          params[:user_pin] = cookies.encrypted[:user_pin]
        end
        # Lo envia a la pag principal
        return redirect_to root_path
      end
    else
      if cookies.encrypted[:room_uid] && cookies.encrypted[:room_uid] == params[:room_uid]
        params[:user_name] = cookies.encrypted[:user_name]
        params[:user_pin] = cookies.encrypted[:user_pin]
      end
    end

    @room = Room.includes(:owner).find_by!(uid: params[:room_uid])
  end

  # Ensure the user either owns the room or is an admin of the room owner or the room is shared with him
  def verify_room_ownership_or_admin_or_shared
    return redirect_to root_path unless @room.owned_by?(current_user) ||
                                        room_shared_with_user ||
                                        current_user&.admin_of?(@room.owner, "can_manage_rooms_recordings")
  end

  # Ensure the user either owns the room or is an admin of the room owner
  def verify_room_ownership_or_admin
    return redirect_to root_path if !@room.owned_by?(current_user) &&
                                    !current_user&.admin_of?(@room.owner, "can_manage_rooms_recordings")
  end

  # Ensure the user owns the room or is allowed to start it
  def verify_room_ownership_or_shared
   return redirect_to root_path unless @room.owned_by?(current_user) || room_shared_with_user
  end

  def validate_accepted_terms
    redirect_to terms_path if current_user && !current_user&.accepted_terms
  end

  def validate_verified_email
    redirect_to account_activation_path(current_user) if current_user && !current_user&.activated?
  end

  def verify_room_owner_verified
    redirect_to root_path, alert: t("room.unavailable") unless @room.owner.activated?
  end

  # Check to make sure the room owner is not pending or banned
  def verify_room_owner_valid
    redirect_to root_path, alert: t("room.owner_banned") if @room.owner.has_role?(:pending) || @room.owner.has_role?(:denied)
  end

  def verify_user_not_admin
    redirect_to admins_path if current_user&.has_role?(:super_admin)
  end

  def auth_required
    @settings.get_value("Room Authentication", session[:organization]) == "true" && current_user.nil?
  end

  # Checks if the room is shared with the user and room sharing is enabled
  def room_shared_with_user
    shared_access_allowed ? @room.shared_with?(current_user) : false
  end

  def room_limit_exceeded
    limit = @settings.get_value("Room Limit", session[:organization]).to_i

    # Does not apply to admin or users that aren't signed in
    # 15+ option is used as unlimited
    return false if current_user&.has_role?(:admin) || limit == 15

    current_user.rooms.length >= limit
  end
  helper_method :room_limit_exceeded
end
