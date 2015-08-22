IP = "94.209.136.195"

_ = require "lodash"
express = require "express"
compress = require "compression"
minify = require "express-minify"
fs = require "fs"
lastfm = require("lastfm").LastFmNode
request = require "request"
github = require("github")

marked = require 'marked'
hljs = require 'highlight.js'
marked.setOptions highlight: (code, lang) -> hljs.highlight(lang, code).value

nowPlaying = null

log = console.log
error = console.error
console.log = (str) -> log "\u001b[90m#{new Date().toISOString()}\u001b[39m #{str}"
console.error = (str) -> error "\u001b[31m#{new Date().toISOString()}\u001b[39m #{str}"

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

# converts minutes to milliseconds.
minutes = (val) -> val * 60 * 1000

lastfmClient = new lastfm
	"api_key": "b68ffcb32c581066eff2eaa6443252d4"
	"secret": "92273fdb7205a5800f44555ddd6cc162"

githubClient = new github version: "3.0.0"

trackStream = lastfmClient.stream("lieuwex")
trackStream.on "nowPlaying", (track) -> nowPlaying = track
trackStream.on "stoppedPlaying", -> nowPlaying = null
trackStream.on "error", (e) -> console.log e
trackStream.start()

githubDate = null
gh = -> githubClient.events.getFromUser { user: "lieuwex" }, (e, r) -> unless e? then githubDate = r[0].created_at.substring 0, 10
gh(); setInterval gh, minutes 20

lastGame = null
league = ->
	request.get "https://euw.api.pvp.net/api/lol/euw/v1.3/game/by-summoner/49307699/recent?api_key=247b1222-b01e-4c55-89a7-fc86973b9084", (err, resp, body) ->
		try
			lastGame = JSON.parse(body).games[0]
			lastGame.url = "http://matchhistory.euw.leagueoflegends.com/en/#match-details/EUW1/#{lastGame.gameId}/41989123"
		catch e
			console.log e
			return

		request.get "https://global.api.pvp.net/api/lol/static-data/euw/v1.2/champion/#{lastGame.championId}?api_key=247b1222-b01e-4c55-89a7-fc86973b9084", (err, resp, body) ->
			try
				lastGame.champName = JSON.parse(body).name
			catch e
				console.log e
				lastGame.champName = undefined

league(); setInterval league, minutes 15

keys = clicks = ""
whatpulse = ->
	request.get "http://api.whatpulse.org/user.php?user=lieuwex&format=json&formatted=yes", (err, resp, body) ->
		return if e?
		try
			parsed = JSON.parse(body)

			keys = parsed.Keys
			clicks = parsed.Clicks
		catch e
			console.log e
			return

whatpulse(); setInterval whatpulse, minutes 120

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
	res.render "me", { nowPlaying, githubDate, lastGame, keys, clicks }

app.get "/post/:post", (req, res) ->
	name = unescape req.params.post
	post = _.find posts, (p) -> p.title is name

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
				res.status(201).end "http://www.lieuwex.me/#{r}"

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
