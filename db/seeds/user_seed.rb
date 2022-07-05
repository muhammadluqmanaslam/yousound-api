if User.find_by_email('zzyy@yopmail.com').nil?
    User.create(email: 'zzyy@yopmail.com', user_type: "artist", username: 'zzuuu', password: 'xyz12345678', status: 'active', display_name: 'Artist ABC',request_role:"artist")
end