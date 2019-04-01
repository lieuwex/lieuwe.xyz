LOCAL_DOMAIN = 'local.lieuwe.xyz'

require './log.coffee'

_ = require 'lodash'
express = require 'express'
minify = require 'express-minify'
fs = require 'fs'
dns = require 'dns'

{ Sources } = require './sources.coffee'
getRss = require './rss.coffee'


# marked
marked = require 'marked'
hljs = require 'highlight.js'
marked.setOptions highlight: (code, lang) -> hljs.highlight(lang, code).value


app = express()


# middlewares
app.set 'view engine', 'pug'

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


# posts
fs.mkdirSync './posts' unless fs.existsSync './posts'

getPosts = ->
	_(fs.readdirSync './posts')
		.filter (fname) ->
			splitted = fname.split '.'
			_.last(splitted) is 'md'

		.map (fname) ->
			f = fs.readFileSync "./posts/#{fname}"
			lines = f.toString().split '\n'

			title: fname.split('.')[0]
			creation: new Date(lines[0]).toISOString().substring 0, 10
			content: marked lines[1..].join '\n'

		.orderBy 'creation', 'desc'
		.value()

posts = getPosts()
rssFeed = getRss posts


pgp = fs.readFileSync './key.asc', encoding: 'utf8'

app.get '/', (req, res) ->
	res.render 'index', { posts }

app.get '/me', (req, res) ->
	res.render 'me',
		nowPlaying: Sources.getLastData 'lastfm'
		githubDate: Sources.getLastData 'github'
		typeracer: Sources.getLastData 'typeracer'

app.get '/post/:post', (req, res) ->
	name = unescape req.params.post
	post = _.find posts, (p) -> p.title.toLowerCase() is name.toLowerCase()

	if post?
		res.render 'post', post
	else if posts.length > 0
		res.status(404).render '404'
	else
		onError e, req, res

app.get '/rss', (req, res) ->
	res.end rssFeed

app.get '/projects', (req, res) ->
	res.render 'projects'

app.get '/resume', (req, res) ->
	res.render 'resume'

app.get '/pgp(.asc)?', (req, res) ->
	res.end pgp

app.get '/local', (req, res) ->
	dns.resolve4 LOCAL_DOMAIN, (err, addrs) ->
		addr = addrs[0]

		if err?
			onError err, req, res
		else if addr?
			res.end "#{addrs[0]}\n"
		else
			res.end ''

# keep as last
app.use (req, res) -> res.status(404).render '404'

port = process.env.PORT || 5000
app.listen port, ->
	console.log "Running on port #{port}"
