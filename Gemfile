source 'https://rubygems.org'


# Bundle edge Rails instead: gem 'rails', github: 'rails/rails'
gem 'rails', '~> 7.1'

# Use SCSS for stylesheets
#gem 'sass-rails' #, '~> 5.0'
# Use Uglifier as compressor for JavaScript assets
gem 'uglifier'#, '>= 1.3.0'
# Use CoffeeScript for .coffee assets and views
# gem 'coffee-rails', '~> 4.1.0'
# See https://github.com/rails/execjs#readme for more supported runtimes
# gem 'therubyracer', platforms: :ruby

# Use jquery as the JavaScript library
gem 'jquery-rails'
# Turbolinks makes following links in your web application faster. Read more: https://github.com/rails/turbolinks
gem 'turbolinks'
# Build JSON APIs with ease. Read more: https://github.com/rails/jbuilder
gem 'jbuilder'#, '~> 2.0'
# bundle exec rake doc:rails generates the API under doc/api.
#gem 'sdoc', '~> 0.4.0', group: :doc

# revert from 3.1.13 due to armhf bug
gem 'bcrypt'#, '3.1.12'

# Use Unicorn as the app server
# gem 'unicorn'

# Use Capistrano for deployment
# gem 'capistrano-rails', group: :development

gem 'httparty'
gem 'rack-cors'
gem 'devise_token_auth'
gem 'devise_invitable'
gem 'oj'  # fast json
gem 'mini_magick'
gem 'bootsnap'
gem 'rubocop-rspec'

# dropped from newer ruby versions so add manually
gem 'mutex_m' 
gem 'base64'
gem 'bigdecimal'
gem 'csv'
gem 'observer'

group :development, :test do
  # Call 'byebug' anywhere in the code to stop execution and get a debugger console
  gem 'byebug'
  gem 'rspec-rails'#, '~> 3.1'
  gem 'rubocop', require: false
  gem 'vcr'
  gem 'webmock'
  gem 'rspec-json_expectations'
  gem 'cucumber-rails', require: false
  gem 'database_cleaner'
  gem 'tzinfo-data'
  gem 'guard'
  gem 'guard-rspec'
  gem 'spring-commands-rspec'
  gem 'terminal-notifier-guard'
  gem 'terminal-notifier'
  gem 'capistrano'#, '~> 3.6'
  gem 'capistrano-rails'#, '~> 1.2'
  gem 'capistrano-rbenv'#, '~> 2.0'
  gem 'capistrano-passenger'
  gem 'thin'
  # dropped from newer ruby versions so add manually
  gem 'drb'
  # development web server
  gem 'puma'
end
group :local, :development, :test do
  gem 'factory_bot_rails'
  gem 'faker'
  # Use sqlite3 as the database for Active Record
  gem 'sqlite3'
  gem 'coveralls', require: false
end

# NOTE: install mailcatcher for development

group :development do
  gem 'guard-rubocop'
  # Access an IRB console on exception pages or by using <%= console %> in views
  gem 'web-console'
  # Spring speeds up development by keeping your application running in the background. Read more: https://github.com/rails/spring
  gem 'spring'
end

group :test do
  gem 'simplecov', :require => false
  gem 'simplecov-console', :require => false
end

group :production do
  # Use postgresql as the database for Active Record
  gem 'pg'
end
