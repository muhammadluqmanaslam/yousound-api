class TrackingPolicy < ApplicationPolicy
  def index?
    true
  end

  def create?
    true
  end

  def dashboard_stats?
    true
  end

  def permitted_attributes
    [
      :duration,
      :track_id,
      :stream_id
    ]
  end
end
