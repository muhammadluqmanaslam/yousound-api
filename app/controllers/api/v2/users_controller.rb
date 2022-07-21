module Api::V2
    class UsersController < ApiController
        skip_after_action :verify_authorized
        skip_after_action :verify_policy_scoped

        swagger_controller :users, 'user'

        swagger_api :demographic_count do |api|
            summary 'list followers group by city'
        end
        def demographic_count
            users = User.followers_by_city_v2(current_user)
            Rails.logger.info("==users_by_cities===")
            Rails.logger.info(users)
            render_success(
                users: ActiveModel::Serializer::CollectionSerializer.new(
                users,
                serializer: UserSerializer,
                scope: OpenStruct.new(current_user: current_user),
                include_social_info: true,
                include_all: true,
                ),
                # pagination: pagination(users)
            )
        end

    end
end