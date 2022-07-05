if User.find_by_email('zzyy@yopmail.com').nil?
    User.create(email: 'zzyy@yopmail.com', user_type: "artist", username: 'zzuuu', password: 'xyz12345678', status: 'active', display_name: 'Artist ABC',request_role:"artist")
end

user = User.find_by_email('rubab@cybernest.com')
user.user_type = 'artist'
user.request_role = 'artist'
user.save