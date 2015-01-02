def give_token
	session[:author] = @author.name
	session[:author_id] = Author.where(name: @author.name)
end

def logged_in?
	session[:author] ? true : false	
end