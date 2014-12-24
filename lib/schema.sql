CREATE TABLE authors (
	id serial primary key, 
	name varchar(75), 
	email varchar(75), 
	vote_total integer
);

CREATE TABLE novels (
	id serial primary key, 
	name varchar(75), 
	author_id integer, 
	synopsis text
);

CREATE TABLE chapters (
	id serial primary key, 
	chapter_number integer, 
	title varchar(250), 
	author_id integer, 
	novel_id integer, 
	locked_in boolean, 
	votes integer, 
	created_at timestamp, 
	content text
);

CREATE TABLE comments (
	id serial primary key,
	author_id integer,
	novel_id integer, 
	chapter_id integer, 
	content varchar(250)
);



