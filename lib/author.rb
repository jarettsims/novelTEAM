require 'active_record'
require 'bcrypt'
require './helpers/give_token'

class Author < ActiveRecord::Base
	include BCrypt

	def password
		@password ||= Password.new(password_hash)
	end

	def password=(new_password)
		@password = Password.create(new_password)
		self.password_hash = @password
	end

end