LOCAL_IP = "94.209.156.25"

require './log.coffee'

_ = require 'lodash'
express = require 'express'
minify = require 'express-minify'
fs = require 'fs'

{ Sources } = require './sources.coffee'

marked = require 'marked'
hljs = require 'highlight.js'
marked.setOptions highlight: (code, lang) -> hljs.highlight(lang, code).value

app = express()
app.set 'view engine', 'jade'

app.use minify()
app.use express.static __dirname + '/public'
app.use '/css', express.static __dirname + '/css'

app.use (req, res, next) ->
	res.header 'Access-Control-Allow-Origin', '*'
	res.header 'Access-Control-Allow-Headers', 'Origin, X-Requested-With, Content-Type, Accept'
	next()

onError = (err, req, res, next) ->
	console.error err.stack
	res.status(500).end 'dat 500 tho.'
app.use onError

posts = []
fs.mkdirSync './posts' unless fs.existsSync './posts'
fs.readdir './posts', (e, files) ->
	return if e?

	posts = []
	files = _.filter files, (f) -> _.last(f.split '.') is 'md'
	for f in files then do (f) ->
		fs.readFile "./posts/#{f}", (e, r) ->
			return if e?

			splitted = r.toString().split '\n'
			posts.push
				title: f.split('.')[0]
				creation: new Date(splitted[0]).toISOString().substring 0, 10
				content: marked splitted[1..].join '\n'

			posts = _(posts)
				.sortBy (p) -> p.creation
				.reverse()
				.value()

pgp = null
fs.readFile './key.asc', { encoding: 'utf8' }, (e, r) ->
	pgp = r unless e?

app.get '/', (req, res) ->
	res.render 'index', { posts }

app.get '/me', (req, res) ->
	whatpulse = Sources.getLastData 'whatpulse'
	typeracer = Sources.getLastData 'typeracer'

	res.render 'me',
		nowPlaying: Sources.getLastData 'lastfm'
		githubDate: Sources.getLastData 'github'

		keys: whatpulse.keys
		clicks: whatpulse.clicks

		bestwpm: typeracer.bestwpm
		averagewpm: typeracer.averagewpm

app.get '/post/:post', (req, res) ->
	name = unescape req.params.post
	post = _.find posts, (p) -> p.title.toLowerCase() is name.toLowerCase()

	if post?
		res.render 'post', post
	else if posts.length > 0
		res.status(404).render '404'
	else
		onError e, req, res

app.get '/projects', (req, res) ->
	res.render 'projects'

app.get '/resume', (req, res) ->
	res.render 'resume'

app.get '/pgp(.asc)?', (req, res) ->
	res.end pgp

app.get '/golocal/:port?/:path?', (req, res) ->
	{ port, path } = req.params

	res.redirect (
		url = "http://#{LOCAL_IP}"
		url += ":#{port}" if port?
		url += "/#{path}" if path?
		url
	)

app.get '/local', (req, res) ->
	res.end LOCAL_IP + '\n'

port = process.env.PORT || 5000
app.listen port, ->
	console.log "Running on port #{port}"
