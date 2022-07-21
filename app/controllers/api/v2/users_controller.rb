module Api::V2
    class UsersController < ApiController
        skip_after_action :verify_authorized
        # skip_after_action :verify_policy_scoped
        swagger_controller :users, 'user'

        swagger_api :demographic_count do |api|
            summary 'Count of followers'
        end
        def demographic_count
            city_counts = User.followers_by_city_v2(current_user)
            age_counts = User.followers_age_count_v2(current_user)
            ageBetween = []
            age1421Count = age2234Count = age3549Count = age5065Count = 0
            a = b = c = d = {}
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
                if age_count.age >= 35 and age_count.age <= 49
                    age3549Count = age3549Count + age_count.count
                    c = {
                        age: '35 - 49',
                        count: age3549Count
                    }
                end
                if age_count.age >= 50
                    age5065Count = age5065Count + age_count.count
                    d = {
                        age: '35 - 49',
                        count: age5065Count
                    }
                end
            end
            ageBetween.append(a)
            ageBetween.append(b)
            ageBetween.append(c)
            ageBetween.append(d)
            render_success( cities: city_counts, age_counts: ageBetween )
        end
    end
end