require 'sinatra'
require 'pry'
require 'active_record'
require 'mustache'
require 'pg'
require './lib/connection.rb'
require './lib/author.rb'
require './lib/novel.rb'
require './lib/chapter.rb'


get '/' do
	Mustache.render(File.read('./views/index.html'))
end

get '/sitemap' do
	Mustache.render(File.read('./views/sitemap.html'))
end

get '/login' do
	Mustache.render(File.read('./views/login.html'))
end

get '/novels/create' do
	Mustache.render(File.read('./views/create_novel.html'))
end

get '/novels/:novel_id' do
	novel = Novel.find("#{params[:novel_id]}")
	Mustache.render(File.read('./views/novel.html'), novel: novel)
end

### PAGE TO SHOW CHAPTER OF A GIVEN NOVEL, WRITTEN BY A SPECIFIC AUTHOR ###
get '/novels/:novel_id/:chapter_number/:author_id' do
	found_chapter = Chapter.where(novel_id: "#{params[:novel_id]}", chapter_number: "#{params[:chapter_number]}", author_id: "#{params[:author_id]}")
	# turn chapter object to an array, then grab the specific instance so it can have getter/setter methods run on it 
	chapter = found_chapter.to_a[0]
	# get book title
	book_title = Novel.find("#{params[:novel_id]}")
	Mustache.render(File.read('./views/read_chapter.html'), chapter: chapter, book_title: book_title)
end

### PAGE TO SHOW ALL LOCKED IN CHAPTERS OF A GIVEN NOVEL ###
get '/novels/:novel_id/read' do
	queried_novel = Chapter.where(novel_id: "#{params[:novel_id]}", locked_in: true)
	binding.pry
end




