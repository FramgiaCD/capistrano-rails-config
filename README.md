#Rails deployment with Capistrano
This repository contains a sample project which can be deployed from local machine as well as [Drone](http://readme.drone.io/usage/overview/) container.
##Preparation
To begin with, we have to add Capistrano and some necessary gems to Gemfile
```
group :staging, :production do
  gem 'capistrano'
  gem 'capistrano-bundler'
  gem 'capistrano-rails'
  gem 'capistrano-rvm'
  gem 'capistrano-sidekiq'
  #Deploy rails using passenger
  gem 'capistrano-passenger'
  gem 'passenger', '>= 5.0.25', require: 'phusion_passenger/rack_handler'
end
```
And after `bundle install`, Capistrano's ready for take the action.
In this case, I use [Passenger](https://www.phusionpassenger.com/) as main Rails application server and the [Unicorn](https://rubygems.org/gems/unicorn/versions/5.1.0) version will be updated soon

##Capistrano configuration
Firstly, we need to initialize some needed files for Capistrano by command
```
$bundle exec cap install
create config/deploy.rb
create config/deploy/staging.rb
create config/deploy/production.rb
mkdir -p lib/capistrano/tasks
create Capfile
Capified
```
###Capfile
Let start with `Capfile`, this file includes all essential library which will be employed during deployment process by Capistrano.
```
# Capfile
# Load DSL and set up stages
require "capistrano/setup"

# Include tasks from other gems included in your Gemfile
require 'capistrano/deploy'
require 'capistrano/rvm'
require 'capistrano/bundler'
require 'capistrano/rails/assets'
require 'capistrano/rails/migrations'
require 'capistrano/passenger'

# Load custom tasks from `lib/capistrano/tasks` if you have any defined
Dir.glob("lib/capistrano/tasks/*.rake").each { |r| import r }
```
Each sub library of Capistrano's responsible for different tasks:
* `capistrano/setup` and `capistrano/deploy`: setup environment and deploy
* `capistrano/rvm`: Ruby library
* `capistrano/bundler`: Bundler supporting
* `capistrano/rails/assets`: For assets task
* `capistrano/rails/migrations`: Task for database migrate files
* `capistrano/passenger`: setup Rails application server based on Passenger

If we want to change to other library, let check out main repo of [Capistrano](https://github.com/capistrano)

###Deploy script
When running `bundle exec cap install`, Capistrano will create for us three main deploy file:
* [config/deploy.rb](https://github.com/FramgiaCD/capistrano-rails-config/blob/master/config/deploy.rb): Contain common tasks, variables for deployment
* [config/deploy/stagging.rb](https://github.com/FramgiaCD/capistrano-rails-config/blob/master/config/deploy/staging.rb) and [config/deploy/production.rb](https://github.com/FramgiaCD/capistrano-rails-config/blob/master/config/deploy/production.rb): Carry spectacular configuration for each environment

For environment variables, we should notice that env variables employed in deploy script is for Capistrano and it should be set on machine take responsibility deployment and after Capistrano has done it works, all these env gone.
So please make sure that, all necessary EVN variables has done on your server to guarantee successful delivery. This is sample task to set up env variables for project using [Dotenv](https://github.com/bkeepers/dotenv)
```ruby
# config/deploy.rb
namespace :deploy do
  ...
  #create symbolic link for server env variables
  desc "link dotenv"
  task :link_dotenv do
    on roles(:app) do
      execute "ln -s /home/deploy/.env #{release_path}/.env"
    end
  end
  before :restart, :link_dotenv
  ...
```

Another important point is about ssh key. Capistrano takes advantage of SSH to do its job so please make sure that our public key has placed in `.ssh/authorized_keys` on server.

##Deployment
For usual case, we always use the command `cap production deploy` to deliver our code to production environment.
However, if you wanna integrate your project with CD system based on Drone, let add a configuration file (`.drone.yml`) for Drone to your project
```yml
build:
  image: framgia/rails-workspace
  commands:
    - bundle install
    - RAILS_ENV=test rake db:create
    - RAILS_ENV=test rake db:migrate
    - rake cucumber
  environemnt:
    DATABASE_USERNAME_TEST: test
    DATABASE_PASSWORD_TEST: test
    DATABASE_DB_NAME_TEST: demo
    DATABASE_HOSTNAME_TEST: 127.0.0.1

compose:
  database:
    image: mysql
    environment:
      MYSQL_DATABASE: demo
      MYSQL_USER: test
      MYSQL_PASSWORD: test
      MYSQL_ROOT_PASSWORD: root

deploy:
  capistrano:
    image: fdplugins/capistrano
    when:
      branch: deploy
    commands:
      - cap production deploy
cache:
  mount:
    - .git
    - vendor
```
The Drone server will listen your changes on project (new push, new tag, new merge...)
and execute action based on your Drone configuration file and execute based on your Drone configuration file.
Basically, Drone workflow include two main parts:
* Integration test: This part is specified by `build` part, for this project I used [Cucumber](https://github.com/cucumber/cucumber-rails)
and it requires availability of `mysql` which define in `compose` part. Drone server will build a Docker container just for running test.
If all the test pass, deploy process will move to next stage
* Deployment: With `deploy`, everything you need it redefine which github branch for deployment and the command for deployment

And finally, we need to active the project on Drone server and add permission to access production/staging server from Drone by copy and paste Drone SSH key to your sever
