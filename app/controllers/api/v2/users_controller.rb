module Api::V2
    class UsersController < ApiController
        skip_after_action :verify_authorized
        # skip_after_action :verify_policy_scoped
        swagger_controller :users, 'user'

        swagger_api :demographic_count do |api|
            summary 'list followers group by city'
        end
        def demographic_count
            city_counts = User.followers_by_city_v2(current_user)
            age_counts = User.followers_age_count_v2(current_user)
            ageBetween = []
            age1421Count = 0
            age2234Count = 0
            a = b = {}
            for age_count in age_counts do
                if age_count.age >= 14 and age_count.age <= 23
                    age1421Count = age1421Count + age_count.count
                    a = {
                        age: '14 - 21',
                        count: age1421Count
                    }
                end
                if age_count.age >= 22 and age_count.age <= 34
                    age2234Count = age2234Count + age_count.count
                    b = {
                        age: '22 - 34',
                        count: age2234Count
                    }
                end
            end
            ageBetween.append(a)
            ageBetween.append(b)
            render_success( cities: city_counts, age_counts: ageBetween )
        end
    end
end