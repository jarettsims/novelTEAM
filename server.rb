require 'sinatra'
require 'pry'
require 'active_record'
require 'mustache'
require 'pg'
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
	Mustache.render(File.read('./views/index.html'))
end

### WELCOME ### (for users who have signed in)
get '/welcome' do
	novels = Novel.all.to_a
	Mustache.render(File.read('./views/welcome.html'), novels: novels)
end

### SITEMAP ###
get '/sitemap' do
	Mustache.render(File.read('./views/sitemap.html'))
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

	if Author.exists?(name: params[:name].downcase, email: params[:email].downcase, password: params[:password])  
		"user already exists"
	else
		#call the new create method
		Author.create(name: params[:name].downcase, email: params[:email].downcase, password: params[:password])
		redirect '/login'
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

### CREATE NEW NOVEL PAGE ###
get '/novels/create' do
	Mustache.render(File.read('./views/create_novel.html'))
end

### SEND INFO ABOUT NEWLY CREATED NOVEL TO THE SERVER ###
post '/novels/create' do
	author_id = session[:author_id].to_a[0].id 
	newly_creatd_novel = Novel.create(name: params[:novel_title], author_id: author_id, synopsis: params[:synopsis])
	Character.create(novel_id: newly_creatd_novel.id, name: params[:character_name], age: params[:character_age], height: params[:character_height], hometown: params[:hometown], backstory: params[:backstory])
	#should have it redirect to '/novels/:novel_id' but having trouble with interpolation in redirect same as with other similar desired redirects
	redirect '/welcome'
end

### DEDICATED NOVEL PAGE ###
get '/novels/:novel_id' do
	novel = Novel.find("#{params[:novel_id]}")
	#get locked chapters
	locked_in_chapters = Chapter.where(locked_in: true, novel_id: params[:novel_id]).to_a

	read_locked = ""

	if locked_in_chapters == []
		last_locked_in_chapter = 0
		read_locked = "Chapter 1 is yet to have been locked in"
	else
		last_locked_in_chapter = "#{locked_in_chapters.last.chapter_number}"
	end
	
	# <a href="/novels/{{novel_id}}/read"><p>{{read_locked}}</p></a>

	next_chapter = (last_locked_in_chapter.to_i + 1)

	#show chapters being written
	currently_being_written_chapters = Chapter.where(novel_id: params[:novel_id], chapter_number: next_chapter).to_a

	authors = []
	locked_in_chapters.each do |chapter|
		authors << Author.find(chapter[:author_id]).name
	end

	Mustache.render(File.read('./views/novel.html'), novel: novel, novel_id: params[:novel_id], locked_in_chapters: locked_in_chapters, next_chapter_number: next_chapter, currently_being_written: currently_being_written_chapters, username: authors)
end

### READ CHAPTER OF A GIVEN NOVEL, WRITTEN BY A SPECIFIC AUTHOR ###
get '/novels/:novel_id/:chapter_number/:author_id/read' do
	found_chapter = Chapter.where(novel_id: params[:novel_id], chapter_number: params[:chapter_number], author_id: params[:author_id])
	# turn chapter object to an array, then grab the specific instance so it can have getter/setter methods run on it 
	chapter = found_chapter.to_a[0]
	# get book title
	book_title = Novel.find(params[:novel_id])
	#get author's name
	author = Author.find(params[:author_id])
	author_name = author.name
	author_id = params[:author_id]

	Mustache.render(File.read('./views/read_chapter.html'), chapter: chapter, book_title: book_title, author: author_name, author_id: author_id)
end

### VOTE ON A CHAPTER ###
post '/novels/:novel_id/:chapter_number/:author_id/vote' do
	logged_in_user_author_id = session[:author_id].to_a[0].id 
	chapter = Chapter.where(novel_id: params[:novel_id], chapter_number: params[:chapter_number], author_id: params[:author_id]).to_a[0]
	id_of_chapter_being_voted_on = chapter[:id]
	binding.pry

	#has the signed in user voted on the given chapter already?
	unless Vote.exists?(author_id: logged_in_user_author_id, novel_id: params[:novel_id], chapter_id: id_of_chapter_being_voted_on)
		#create a new vote
		Vote.create(author_id: logged_in_user_author_id, novel_id: params[:novel_id], chapter_id: chapter_id) 
		#add the vote to the chapter's vote total
		chapter.votes += 1
		chapter.save
	end

	redirect '/welcome'
	## another case of redirect not working as intended:
	# redirect '/novels/params[:novel_id]/params[:chapter_number]/params[:author_id]/read'
end

### READ ALL LOCKED IN CHAPTERS OF A GIVEN NOVEL ###
get '/novels/:novel_id/read' do
	book_title = Novel.find("#{params[:novel_id]}")

	queried_novel = Chapter.where(novel_id: "#{params[:novel_id]}", locked_in: true)
	chapters = queried_novel.to_a.sort

	Mustache.render(File.read('./views/read_novel.html'), book_title: book_title, chapter: chapters)
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
	# binding.pry
	Mustache.render(File.read('./views/author.html'), author: author)
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
