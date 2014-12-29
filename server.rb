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

## SIGNUP PAGE###
get '/signup' do
	Mustache.render(File.read('./views/signup.html'))
end

post '/signup' do
	if Author.exists?(name: params[:name].downcase, email: params[:email].downcase)  
		"user already exists"
	else
		Author.create(name: params[:name].downcase, email: params[:email].downcase)
		"Thanks for signing up"
		redirect '/login'
	end 
end

## LOGIN PAGE###
get '/login' do
	Mustache.render(File.read('./views/login.html'))
end

post '/login' do
	if Author.exists?(name: params[:name].downcase, email: params[:email].downcase)
		author_id = Author.where(name: params[:name].downcase, email: params[:email].downcase).to_a[0].id  
		"You are now signed in"
		redirect '/'
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
	author_id = Author.where(name: params[:author_name], email: params[:author_email]).to_a[0][:id]
	newly_creatd_novel = Novel.create(name: params[:novel_title], author_id: author_id, synopsis: params[:synopsis])
	Character.create(novel_id: newly_creatd_novel.id, name: params[:character_name], age: params[:character_age], height: params[:character_height], hometown: params[:hometown], backstory: params[:backstory])
end

### DEDICATED NOVEL PAGE ###
get '/novels/:novel_id' do
	novel = Novel.find("#{params[:novel_id]}")
	#get locked chapters
	locked_in_chapters = Chapter.where(locked_in: true, novel_id: params[:novel_id]).to_a
	if locked_in_chapters == []
		last_locked_in_chapter = 0
	else
		last_locked_in_chapter = "#{locked_in_chapters.last.chapter_number}"
	end

	next_chapter = (last_locked_in_chapter.to_i + 1)

	#show chapters being written
	currently_being_written_chapters = Chapter.where(novel_id: params[:novel_id], chapter_number: next_chapter).to_a

	authors = []
	locked_in_chapters.each do |chapter|
		authors << Author.find(chapter[:author_id])
	end

	Mustache.render(File.read('./views/novel.html'), novel: novel, novel_id: params[:novel_id], locked_in_chapters: locked_in_chapters, next_chapter_number: next_chapter, currently_being_written: currently_being_written_chapters)
	
	# username: authors

	## get authors' usernames that correspond to the locked_in chapters' id and put each name into an array

end

### READ CHAPTER OF A GIVEN NOVEL, WRITTEN BY A SPECIFIC AUTHOR ###
get '/novels/:novel_id/:chapter_number/:author_id/read' do
	found_chapter = Chapter.where(novel_id: "#{params[:novel_id]}", chapter_number: "#{params[:chapter_number]}", author_id: "#{params[:author_id]}")
	# turn chapter object to an array, then grab the specific instance so it can have getter/setter methods run on it 
	chapter = found_chapter.to_a[0]
	# get book title
	book_title = Novel.find("#{params[:novel_id]}")
	Mustache.render(File.read('./views/read_chapter.html'), chapter: chapter, book_title: book_title)
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

	author_id = Author.where(name: params[:name], email: params[:email]).to_a[0][:id]

	Chapter.create(chapter_number: params[:chapter_number], title: params[:title], author_id: author_id, novel_id: params[:novel_id], votes: 0, created_at: Time.now, content: params[:content])
	### there needs to be a hard value in the redirect address, which is why interpolation is used here:
	redirect '/novels/#{params[:novel_id]}'
end

### AUTHOR'S PERSONAL PAGE ###
get '/authors/:id' do
	author = Author.find(params[:id])
	Mustache.render(File.read('./views/author.html'), author: author)
end

put '/novels/:novel_id/:chapter_number/edit' do
	"you're on the edit page"
end

