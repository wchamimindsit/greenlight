class SharedController < ApplicationController

  # GET /:show_message
  # type_message: [success, alert, maintenance, info]
  def show_message
    begin    
      unless !(!params[:message].nil? && !params[:type_message].nil?)

        k = params[:type_message]
        v = params[:message]
        flash.now[k]=v

        render partial: 'shared/flash_messages', flash: flash, formats: :html, layout: false
      else
        render body: ' ', formats: :html
      end
    rescue => e
      logger.error "Support: Error in show_message: #{e}"
    end    
  end
    
end