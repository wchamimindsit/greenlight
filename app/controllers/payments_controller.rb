class PaymentsController < ApplicationController
    
    skip_before_action :verify_authenticity_token

    # POST /# PUT /
    def confirmed
        
        logger.info "------------------------------------------------"
        logger.info params.to_json
        logger.info "------------------------------------------------"

        #objReturn = {update: "ok"}
        #respond_to do |format|
        #    format.json { render body: objReturn.to_json }
        #end

        redirect_to root_path

    end
end