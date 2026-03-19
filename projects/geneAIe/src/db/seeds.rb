User.find_or_create_by!(email_address: "admin@sovereign.local") do |user|
  user.password = "sovereign-poc-2026"
  user.password_confirmation = "sovereign-poc-2026"
end

puts "Seed user created: admin@sovereign.local"
