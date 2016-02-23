module Backend
  module Cells
    class StewardshipCellsController < Backend::Cells::BaseController
      def show
        @campaigns = if params[:campaign_id]
                       [Campaign.find(params[:campaign_id])]
                     elsif params[:current_campaign_id]
                       [Campaign.find(params[:current_campaign_id])]
                     elsif current_campaign
                       [current_campaign]
                     else
                       [Campaign.current.last]
                     end
      end
    end
  end
end
