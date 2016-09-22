# config valid only for current version of Capistrano
lock '3.6.1'

set :application, 'my_app_name'
set :repo_url, 'git@example.com:me/my_repo.git'

set :rvm_ruby_version, "2.3.1"
set :deploy_to, "/home/deploy/rails_apps/#{fetch :application}"
set :passenger_roles, :app
set :passenger_restart_runner, :sequence
set :passenger_restart_wait, 5
set :passenger_restart_limit, 2
set :passenger_restart_with_sudo, false
set :passenger_environment_variables, {}
set :passenger_restart_command, "passenger-config restart-app"
set :passenger_restart_options, -> { "#{deploy_to} --ignore-app-not-running --rolling-restart" }

# NOTE: public/uploads IS USED ONLY FOR THE STAGING ENVIRONMENT
set :linked_dirs, %w(bin log tmp/pids tmp/cache tmp/sockets vendor/bundle public/system public/uploads)

set :default_env, {
  database_db_name: ENV["DATABASE_DB_NAME"],
  database_hostname: ENV["DATABASE_HOSTNAME"],
  database_username: ENV["DATABASE_USERNAME"],
  database_password: ENV["DATABASE_PASSWORD"],
}

namespace :deploy do
  desc "create database"
  task :create_database do
    on roles(:db) do |host|
      within "#{release_path}" do
        with rails_env: ENV["RAILS_ENV"] do
          execute :rake, "db:create"
        end
      end
    end
  end
  before :migrate, :create_database

  #create symbolic link for server env variables
  desc "link dotenv"
  task :link_dotenv do
    on roles(:app) do
      execute "ln -s /home/deploy/.env #{release_path}/.env"
    end
  end
  before :restart, :link_dotenv


  desc "Restart application"
  task :restart do
    on roles(:app), in: :sequence, wait: 5 do
      invoke "passenger:restart"
    end
  end
  after :publishing, :restart
end
