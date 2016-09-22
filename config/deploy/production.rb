username = ENV['PRODUCTION_USERNAME']
servername = ENV['SERVER_NAME']

set :branch, ENV["PRODUCTION_BRANCH"]
set :passenger_restart_with_touch, true
role :app, %W{#{username}@#{servername}}
role :web, %W{#{username}@#{servername}}
role :db,  %W{#{username}@#{servername}}

# Define server(s)
server "#{servername}", user: "#{username}", roles: %w{web}

# Define ssh option for remote deployment
# Can be used for both local deployment as well as drone container
set :ssh_options, {
  forward_agent: true,
  keys: File.join(ENV["HOME"], ".ssh", "id_rsa")
}
