require 'active_record'

if ENV["DB_INFO"] 
ActiveRecord::Base.establish_connection('postgresql://' + ENV["DB_INFO"] + '@127.0.0.1/novelteam')
ActiveRecord::Base.logger = Logger.new(STDOUT)
else
ActiveRecord::Base.establish_connection({
  :adapter => "postgresql", #can work with any type of sql database. List the type here.
  :host => "localhost", #running it on the ip listed address (in this place localhost, whcih is a synonym for 127.0.0.1)
  :username => "Jarett", # your psql username
  :database => "novelteam" #we're explicitly giving it the name of the database we want to connect to.
})
end