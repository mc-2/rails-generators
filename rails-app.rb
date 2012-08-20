# Rails Application Generator Template
# Usage: rails new APP_NAME -m https://github.com/mc-2/rails-generators/raw/master/rails-app.rb -T

#################################################
# create .rvmrc that has new gemset
#################################################
create_file '.rvmrc' do
    <<-STR
rvm use --create --install 1.9.3@#{@app_name}
STR
end

#################################################
# Autoload lib
#################################################
inject_into_file 'config/application.rb', :after => 'config.autoload_paths += %W(#{config.root}/extras)' do <<-'RUBY'
    config.autoload_paths += %W(#{config.root}/lib)
RUBY
end

#################################################
# remove and create a new database file for MySQL
#################################################
remove_file 'config/database.yml'
create_file 'config/database.yml' do
  <<-STR
test: &test
  adapter: mysql2
  encoding: utf8
  host: localhost
  database: #{@app_name}_test
  username: root
  password:

development:
  <<: *test
  database: #{@app_name}_development
STR
end


#################################################
# Add gems to Gemfile
#################################################
remove_file "Gemfile"
create_file "Gemfile" do
  <<-RUBY
source 'https://rubygems.org'
gem 'active_model_serializers'
gem 'cancan'
gem 'devise'
gem 'haml'
gem 'jquery-rails'
gem 'kaminari'
gem 'mysql2'
gem 'rails'
gem 'simple_form'
gem 'yettings'

group :test do
  gem "factory_girl_rails"
  gem "growl"
  gem "guard-rspec"
  gem "guard-spork"
  gem "resque_spec"
  gem "rspec-rails"
  gem "shoulda-matchers"
  gem "simplecov"
  gem "spork"
end

group :assets do
  gem 'sass-rails',   '~> 3.2.3'
  gem 'coffee-rails', '~> 3.2.1'
  gem 'uglifier', '>= 1.0.3'
end
  RUBY
end

run 'bundle install'
run 'bundle update'


#################################################
# Initialize Guard
#################################################
run "guard init"
remove_file "Guardfile"
create_file "Guardfile" do
<<-'STR'
guard 'rspec', :cli => "--drb --format doc --color" do
  watch(%r{^spec/.+_spec\.rb$})
  watch(%r{^lib/(.+)\.rb$})     { |m| "spec/lib/#{m[1]}_spec.rb" }
  watch('spec/spec_helper.rb')  { "spec" }
  watch(%r{^app/(.+)\.rb$})                           { |m| "spec/#{m[1]}_spec.rb" }
  watch(%r{^app/(.*)(\.erb|\.haml)$})                 { |m| "spec/#{m[1]}#{m[2]}_spec.rb" }
  watch(%r{^app/controllers/(.+)_(controller)\.rb$})  { |m| ["spec/routing/#{m[1]}_routing_spec.rb", "spec/#{m[2]}s/#{m[1]}_#{m[2]}_spec.rb", "spec/acceptance/#{m[1]}_spec.rb"] }
  watch(%r{^spec/support/(.+)\.rb$})                  { "spec" }
  watch('config/routes.rb')                           { "spec/routing" }
  watch('app/controllers/application_controller.rb')  { "spec/controllers" }
end

guard 'spork', :rspec_env => { 'RAILS_ENV' => 'test' } do
  watch('config/application.rb')
  watch('config/environment.rb')
  watch('config/environments/test.rb')
  watch(%r{^config/initializers/.+\.rb$})
  watch('Gemfile')
  watch('Gemfile.lock')
  watch('spec/spec_helper.rb') { :rspec }
end
STR
end


#################################################
# Create the database
#################################################
rake "db:create"



#################################################
# Install devise
#################################################
generate "devise:install"
route "devise_for :users"


#################################################
# obfuscate password_confirmation in logfiles
#################################################
gsub_file 'config/application.rb', /:password/, ':password, :password_confirmation'


#################################################
# add denied route for CanCan
#################################################
inject_into_file 'app/controllers/application_controller.rb', :before => 'end' do <<-RUBY
  rescue_from CanCan::AccessDenied do |exception|
    redirect_to root_path, :alert => exception.message
  end
RUBY
end


#################################################
# remove index file and create root route
#################################################
remove_file 'public/index.html'
create_file 'app/controllers/home_controller.rb' do
  <<-RUBY
class HomeController < ApplicationController
end
  RUBY
end
create_file 'app/views/home/index.html.haml' do
    <<-'HAML'
%h3 Home
HAML
end

route "root :to => 'home#index'"


#################################################
# delete files we don't need
#################################################
%w{
  README
  doc/README_FOR_APP
  public/index.html
  app/assets/images/rails.png
}.each { |file| remove_file file }


#################################################
# remove double blank lines and comments
#################################################
gsub_file 'config/routes.rb', /  #.*\n/, "\n"
gsub_file 'config/routes.rb', /\n^\s*\n/, "\n"


#################################################
# install rspec
#################################################
run "rm -Rf test"
generate 'rspec:install'
create_file 'spec/support/devise.rb' do
  <<-RUBY
RSpec.configure do |config|
  config.include Devise::TestHelpers, :type => :controller
end
RUBY
end

run "mkdir spec/models"
run "mkdir spec/controllers"
run "mkdir spec/requests"
run "mkdir spec/serializers"
run "mkdir spec/routing"
run "mkdir spec/factories"

remove_file "spec/spec_helper.rb"
create_file "spec/spec_helper.rb" do
<<-RUBY
require 'spork'

Spork.prefork do
  require 'simplecov'
  SimpleCov.start do
    add_filter "/spec/"
  end

  ENV["RAILS_ENV"] ||= 'test'

  require File.expand_path('../../config/environment', __FILE__)

  require 'rspec/rails'
  require 'rspec/autorun'
  require 'factory_girl'
  require "cancan/matchers"
  require "shoulda-matchers"

  Dir[Rails.root.join("spec/support/**/*.rb")].each {|f| require f}

  RSpec.configure do |config|
    config.mock_with :rspec
    config.use_transactional_fixtures = true
    config.filter_run_excluding :external => true
    config.infer_base_class_for_anonymous_controllers = false
  end
end

Spork.each_run do
  FactoryGirl.reload
end
RUBY
end

remove_file ".rspec"
create_file ".rspec" do
<<-RUBY
--color
--format documentation
RUBY
end


#################################################
# install rspec
#################################################
create_file 'spec/support/devise.rb' do
  <<-RUBY
RSpec.configure do |config|
  config.include Devise::TestHelpers, :type => :controller
end
RUBY
end


#################################################
# create db and migrate
#################################################
rake "db:migrate"
rake "db:test:prepare"
rake "db:seed"


#################################################
# add git repo
#################################################
git :init
git :add => "."
git :commit => "-a -m 'Initial commit'"
