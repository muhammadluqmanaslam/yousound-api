module Api::V1
  class TrackingsController < ApiController
    skip_after_action :verify_authorized

    def index
      @trackings = Tracking.all
    end

    def dashboard_stats
      @play = Tracking.most_listened_creators(current_user)

      render json: @play.first(10)
    end

    def create
      @tracking = Tracking.new(listener_id: current_user.id, creator_id: creator)
      authorize @tracking

      attributes = permitted_attributes(@tracking)

      if @tracking.creator_id != @tracking.listener_id && @tracking.update(attributes)
        render_success true
      else
        render_error 'Something went wrong.', :unprocessable_entity
      end
    end

    private

    def creator
      return Track.find_by_id(params[:track_id]).user&.id if params[:track_id].present?

      Stream.find_by_id(params[:stream_id]).user&.id if params[:stream_id].present?
    end
  end
end
