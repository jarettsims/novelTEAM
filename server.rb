require 'sinatra'
require 'pry'
require 'active_record'
require 'mustache'
require 'pg'
require 'twilio-ruby'
require './lib/connection.rb'
require './lib/author.rb'
require './lib/novel.rb'
require './lib/chapter.rb'
require './lib/character'
require './lib/vote.rb'
require './helpers/give_token'

enable :sessions

### HOME/ROOT ### (for users/visitors who have NOT signed in)
get '/' do 
	
	welcome = ""
	in_or_out_text = ""
	in_or_out_path = ""
	signup_or_welcome_path = ""
	signup_or_welcome_text = ""

	if logged_in?
		welcome = "/welcome"
		in_or_out_text = "Logout"
		in_or_out_path = "logout"
		signup_or_welcome_path = "welcome"
		signup_or_welcome_text = "Enter Site"
	else
		welcome = "#"
		in_or_out_text = "Login"
		in_or_out_path = "login"
		signup_or_welcome_path = "signup"
		signup_or_welcome_text = "Signup & Become a TEAM Player"
	end

	Mustache.render(File.read('./views/index.html'), welcome: welcome, in_or_out_text: in_or_out_text, in_or_out_path: in_or_out_path, signup_or_welcome_text: signup_or_welcome_text, signup_or_welcome_path: signup_or_welcome_path)
end

### WELCOME ### (for users who have signed in)
get '/welcome' do
	logged_in_users_name = session[:author_id].to_a[0].name
	logged_in_users_author_id = session[:author_id].to_a[0].id
	novels = Novel.all.to_a

	Mustache.render(File.read('./views/welcome.html'), novels: novels, logged_in_user: logged_in_users_name, author_id: logged_in_users_author_id)
end

### SIGNUP PAGE ###
get '/signup' do
	Mustache.render(File.read('./views/signup.html'))
end

### SEND SIGNUP DETAILS TO THE SERVER TO CREATE A NEW USER ###
post '/signup' do
	#using the bcrypt gem as per the instructions in the documentation
	#REdefine the create method like you would the to_s method, making each author an instance of the author class
	def create
		@author = Author.new(params[:name])
		@author.email = params[:email]
		@author.password = params[:password]
		@author.save!
	end

	if Author.exists?(name: params[:name].downcase, email: params[:email].downcase, password_hash: params[:password])  
		"user already exists"
	else
		#call the new create method
		Author.create(name: params[:name].downcase, email: params[:email].downcase, password: params[:password])
		session[:author] = params[:name] 
		# binding.pry
		session[:author_id] = Author.where(name: session[:author])

		redirect '/welcome'
	end 
end

## LOGIN PAGE###
get '/login' do
	Mustache.render(File.read('./views/login.html'))
end

### AUTHENTICATE USER, GIVE TOKEN TO AUTHOR (START SESSION) IF PASSWORD MATCHES ENCRYPTED STORED PASSWORD ###
post '/login' do	
	@author = Author.find_by_email(params[:email])
	if @author.password == params[:password]
		#give_token is a helper method stored in the helpers dir
		give_token
		"You're logged in"
		redirect '/welcome'
	else
		"Incorrect login credentials. Please try again, or signup to create a new account."
		redirect '/login'
	end
end

get '/logout' do
	session.clear
	redirect '/'
end

### CREATE NEW NOVEL PAGE ###
get '/novels/create' do
	logged_in_user_id = session[:author_id].to_a[0].id
	Mustache.render(File.read('./views/create_novel.html'), logged_in_user_id: logged_in_user_id)
end

### SEND INFO ABOUT NEWLY CREATED NOVEL TO THE SERVER ###
post '/novels/create' do
	author_id = session[:author_id].to_a[0].id
	
	cover_url = ""
	if params[:cover_url] == ""
		cover_url = nil
	else
		cover_url = params[:cover_url]
	end
	newly_creatd_novel = Novel.create(name: params[:novel_title], author_id: author_id, synopsis: params[:synopsis], cover_url: cover_url)
	Character.create(novel_id: newly_creatd_novel.id, name: params[:character_name], age: params[:character_age], height: params[:character_height], hometown: params[:hometown], backstory: params[:backstory])
	#should have it redirect to '/novels/:novel_id' but having trouble with interpolation in redirect same as with other similar desired redirects
	redirect '/welcome'
end

### DEDICATED NOVEL PAGE ###
get '/novels/:novel_id' do
	novel = Novel.find(params[:novel_id])
	author_who_created_novel = Author.where(id: novel.author_id).to_a[0]
	name_of_author_who_created_novel = author_who_created_novel.name
	id_of_author_who_created_novel = author_who_created_novel.id

	#get locked chapters
	locked_in_chapters = Chapter.where(locked_in: true, novel_id: params[:novel_id]).to_a
	read_locked = ""

	if locked_in_chapters == []
		last_locked_in_chapter = 0
		read_locked = "Chapter 1 is yet to have been locked in"
	else
		last_locked_in_chapter = "#{locked_in_chapters.last.chapter_number}"
	end
	
	next_chapter = (last_locked_in_chapter.to_i + 1)

	#show chapters being written
	currently_being_written_chapters = Chapter.where(novel_id: params[:novel_id], chapter_number: next_chapter).to_a

	authors = locked_in_chapters.map { |chapter| Author.find(chapter[:author_id]).name}
	novel_img = "placeholder"
	# binding.pry
	if novel.cover_url == nil
		novel_img = "http://i211.photobucket.com/albums/bb117/Archeaglefly/curtains-closed-1.jpg"
	else
		novel_img = novel.cover_url
	end

	# Mustache.render(File.read('./public/stylesheets/main.css'), novel_img: novel_img)
	Mustache.render(File.read('./views/novel.html'), novel: novel, novel_id: params[:novel_id], logged_in_user_id: session[:author_id].to_a[0].id, locked_in_chapters: locked_in_chapters, next_chapter_number: next_chapter, currently_being_written: currently_being_written_chapters, username: authors, novel_img: novel_img, name_of_author_who_created_novel: name_of_author_who_created_novel, id_of_author_who_created_novel: id_of_author_who_created_novel)
end

### READ CHAPTER OF A GIVEN NOVEL, WRITTEN BY A SPECIFIC AUTHOR ###
get '/novels/:novel_id/:chapter_number/:author_id/read' do
	logged_in_user_id = session[:author_id].to_a[0].id
	chapter = Chapter.where(novel_id: params[:novel_id], chapter_number: params[:chapter_number], author_id: params[:author_id]).to_a[0]
	# get book title
	book_title = Novel.find(params[:novel_id])
	#get author's name
	author = Author.find(params[:author_id])
	author_name = author.name
	author_id = params[:author_id]
	
	Mustache.render(File.read('./views/read_chapter.html'), novel_id: params[:novel_id], chapter: chapter, book_title: book_title, author: author_name, author_id: author_id, logged_in_user_id: logged_in_user_id)
end

### VOTE ON A CHAPTER ###
post '/novels/:novel_id/:chapter_number/:author_id/vote' do
	logged_in_user_author_id = session[:author_id].to_a[0].id 
	chapter = Chapter.where(novel_id: params[:novel_id], chapter_number: params[:chapter_number], author_id: params[:author_id]).to_a[0]
	id_of_chapter_being_voted_on = chapter[:id]

	#has the signed in user voted on the given chapter already?
	unless Vote.exists?(author_id: logged_in_user_author_id, novel_id: params[:novel_id], chapter_id: id_of_chapter_being_voted_on)
		#create a new vote
		Vote.create(author_id: logged_in_user_author_id, novel_id: params[:novel_id], chapter_id: id_of_chapter_being_voted_on) 
		#add the vote to the chapter's vote total
		chapter.votes += 1
		chapter.save
	end
	# redirect '/welcome'
	## another case of redirect not working as intended:
	# binding.pry
	redirect "/novels/#{params[:novel_id]}/#{params[:chapter_number]}/#{params[:author_id]}/read"
end

### READ ALL LOCKED IN CHAPTERS OF A GIVEN NOVEL ###
get '/novels/:novel_id/read' do
	book_title = Novel.find(params[:novel_id])

	novel = Chapter.where(novel_id: params[:novel_id], locked_in: true)
	chapters = novel.to_a.sort
	# authors_of_locked_chapters = chapters.map { |x| Author.find(x.author_id).name}
	author = ""
	chapters.each do |chapter|
		author = Author.find(chapter.author_id).name
	end
	
	Mustache.render(File.read('./views/read_novel.html'), book_title: book_title, chapter: chapters, author: author)
end

### PAGE TO WRITE A SPECIFIC CHAPTER NUMBER FOR A SPECIFIED NOVEL ###
get '/novels/:novel_id/:chapter_number/write' do
	novel = Novel.find(params[:novel_id])

	Mustache.render(File.read('./views/write_chapter.html'), novel_id: params[:novel_id].to_i, chapter_number: params[:chapter_number].to_i, name_of_novel: novel.name)
end

### SEND WRITTEN CHAPTER FOR A SPECIFIED NOVEL TO THE SERVER ###
post '/novels/:novel_id/:chapter_number/write' do
	#if user has already created a chapter for the given novel, redirect them to the edit page with content from said chapter populated on the page
	# if Chapter.exists?(novel_id: params[:novel_id], chapter_number: params[:chapter_number], author_id: author_id)   
	
	# novel_id_as_integer = params[:novel_id].to_i 

	author_id = session[:author_id].to_a[0].id 

	Chapter.create(chapter_number: params[:chapter_number], title: params[:title], author_id: author_id, novel_id: params[:novel_id], votes: 0, created_at: Time.now, content: params[:content])
	### there needs to be a hard value in the redirect address, which is why interpolation is used here:
	redirect '/welcome'
end

### AUTHOR'S PERSONAL PAGE ###
get '/authors/:id' do
	author = Author.find(params[:id])
	novels_contributed_to = Chapter.where(author_id: author).to_a
	novels_contributed_to.map {|x| x.novel_id}
	logged_in_user_id = session[:author_id].to_a[0].id
	Mustache.render(File.read('./views/author.html'), author: author, logged_in_user_id: logged_in_user_id)
end

### PAGE TO EDIT CHAPTER ###
get '/novels/:novel_id/:chapter_number/:author_id/edit' do

	novel_to_edit = Novel.find(params[:novel_id])
	name_of_novel = novel_to_edit.name
	
	chapter_to_edit = Chapter.where(novel_id: params[:novel_id], chapter_number: params[:chapter_number], author_id: params[:author_id]).to_a[0]

	existing_content = chapter_to_edit.content
	existing_chapter_title = chapter_to_edit.title
	
	Mustache.render(File.read('./views/edit_chapter.html'), name_of_novel: name_of_novel, novel_id: params[:novel_id], chapter_number: params[:chapter_number], author_id: params[:author_id], existing_title: existing_chapter_title, existing_content: existing_content)
end

### SEND CHAPTER EDITS TO THE SERVER ###
put '/novels/:novel_id/:chapter_number/:author_id/edit' do

	chapter_being_edited = Chapter.where(novel_id: params[:novel_id], chapter_number: params[:chapter_number], author_id: params[:author_id]).to_a[0]

	new_title = params[:new_title]
	new_content = params[:new_content]

	chapter_being_edited.title =  new_title
	chapter_being_edited.content = new_content

	chapter_being_edited.save

	redirect '/welcome'
	### why won't redirect to the dedicated novel page work?
	# redirect '/novels/#{params[novel_id]}'
end

### DELETE A CHAPTER OF A GIVEN NOVEL FOR A SPECIFIC AUTHOR ###
delete '/novels/:novel_id/:chapter_number/:author_id/delete' do

	chapter = Chapter.where(novel_id: params[:novel_id], chapter_number: params[:chapter_number], author_id: params[:author_id]).to_a[0]

	chapter.destroy

	redirect '/welcome'
end
