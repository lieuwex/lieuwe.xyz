IP = "94.209.156.25"

require './log.coffee'

_ = require "lodash"
express = require "express"
compress = require "compression"
minify = require "express-minify"
fs = require "fs"

{ Sources } = require './sources.coffee'

marked = require 'marked'
hljs = require 'highlight.js'
marked.setOptions highlight: (code, lang) -> hljs.highlight(lang, code).value

app = express()
app.set "view engine", "jade"

app.use compress filter: -> yes # Compress EVERYTHING
app.use minify()
app.use express.static __dirname + "/public"
app.use "/css", express.static __dirname + "/css"

app.use (req, res, next) ->
	res.header "Access-Control-Allow-Origin", "*"
	res.header "Access-Control-Allow-Headers", "Origin, X-Requested-With, Content-Type, Accept"
	next()

onError = (err, req, res, next) ->
	console.log err.stack
	res.status(500).end "dat 500 tho."
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
fs.readFile "./key.asc", { encoding: "utf8" }, (e, r) ->
	pgp = r unless e?

chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz01234556789"
fs.writeFileSync("./shorted.json", "{}") unless fs.existsSync "./shorted.json"
_shortedLinks = JSON.parse fs.readFileSync "./shorted.json"
_saveShortedLinks = (cb) -> fs.writeFile "./shorted.json", JSON.stringify(_shortedLinks), (e, r) -> cb? e, r
setShorted = (long, cb) ->
	shortName = null
	for x of _shortedLinks
		if _shortedLinks[x] is long
			shortName = x

	if shortName?
		cb undefined, shortName
	else
		arr = new Array 5
		for i in [0...5]
			arr[i] = chars[~~(Math.random() * (chars.length + 1))]
		shortName = arr.join ""

		_shortedLinks[shortName] =
			long: long
			clicks: 0

		_saveShortedLinks (e, r) -> cb e, shortName

	undefined

getShorted = (short) ->
	unless _shortedLinks[short]? then return null

	_shortedLinks[short].clicks++
	_saveShortedLinks()

	_shortedLinks[short].long

app.get "/", (req, res) ->
	res.render "index", { posts }

app.get "/me", (req, res) ->
	whatpulse = Sources.getLastData 'whatpulse'
	typeracer = Sources.getLastData 'typeracer'

	res.render 'me',
		nowPlaying: Sources.getLastData 'lastfm'
		githubDate: Sources.getLastData 'github'

		keys: whatpulse.keys
		clicks: whatpulse.clicks

		bestwpm: typeracer.bestwpm
		averagewpm: typeracer.averagewpm

app.get "/post/:post", (req, res) ->
	name = unescape req.params.post
	post = _.find posts, (p) -> p.title.toLowerCase() is name.toLowerCase()

	if post?
		res.render 'post', post
	else if posts.length > 0
		res.status(404).render '404'
	else
		onError e, req, res

app.get "/projects", (req, res) ->
	res.render "projects"

app.get "/resume", (req, res) ->
	res.render "resume"

app.post "/short", (req, res) ->
	s = ""
	req.on "data", (blob) -> s += blob
	req.on "end", ->
		setShorted s, (e, r) ->
			if e?
				res.status(500).end e.toString()
			else
				res.status(201).end "http://www.lieuwe.xyz/#{r}"

app.get "/golocal/:port?/:path?", (req, res) ->
	url = "http://#{IP}"
	if (port = req.params.port)? then url += ":#{port}"
	if (path = req.params.path)? then url += "/#{path}"
	res.redirect url
app.get "/local", (req, res) -> res.end IP

app.get "/pgp(.asc)?", (req, res) ->
	res.end pgp

# === Don't add routes beneath here, fucked me up enough times.

app.get "/:short", (req, res) ->
	if (val = getShorted req.params.short)? then res.redirect val
	else res.status(404).render "404"

app.get "/:short/stats", (req, res) ->
	if (val = _shortedLinks[req.params.short])?
		res.render "stats",
			short: req.params.short
			long: val.long
			clicks: val.clicks

	else res.status(404).render "404"

port = process.env.PORT || 5000
app.listen port, -> console.log "Running on port #{port}"
