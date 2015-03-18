IP = "94.209.136.195"

_ = require "nimble"
express = require "express"
compress = require "compression"
minify = require "express-minify"
fs = require "fs"
lastfm = require("lastfm").LastFmNode
request = require "request"
github = require("github")
marked = new require("marked")
nowPlaying = null

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
gh(); setInterval gh, 600000

lastGame = null
league = ->
	request.get "https://euw.api.pvp.net/api/lol/euw/v1.3/game/by-summoner/49307699/recent?api_key=247b1222-b01e-4c55-89a7-fc86973b9084", (err, resp, body) ->
		return if e?
		try
			lastGame = JSON.parse(body).games[0]
		catch e
			console.log e
			return
		champId = lastGame.championId

		if lastGame.subType.indexOf("RANKED_") isnt -1 # LoL Matchhistory is usable on ranked games and is way nicer than LoLKing.
			lastGame.url = "http://matchhistory.euw.leagueoflegends.com/en/#match-details/EUW1/#{lastGame.gameId}/41989123"
		else # Normal games on LoL matchhistory are only visible for the players of the match. Use LoLKing instead.
			lastGame.url = "http://www.lolking.net/summoner/euw/49307699#matches/#{lastGame.gameId}"

		request.get "https://global.api.pvp.net/api/lol/static-data/euw/v1.2/champion/#{champId}?api_key=247b1222-b01e-4c55-89a7-fc86973b9084", (err, resp, body) ->
			try
				lastGame.champName = JSON.parse(body).name
			catch e
				console.log e
				lastGame.champName = undefined

league(); setInterval league, 300000

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

whatpulse(); setInterval whatpulse, 1200000

fs.mkdirSync("./posts") unless fs.existsSync "./posts"

chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz01234556789"
fs.writeFileSync("./shorted.json", "{}") unless fs.existsSync "./shorted.json"
_shortedLinks = JSON.parse fs.readFileSync "./shorted.json"
_saveShortedLinks = -> fs.writeFileSync "./shorted.json", JSON.stringify _shortedLinks
setShorted = (long) ->
	shortName = null
	for x of _shortedLinks
		if _shortedLinks[x] is long
			shortName = x

	unless shortName?
		arr = new Array 5
		for i in [0...5]
			arr[i] = chars[~~(Math.random() * (chars.length + 1))]
		shortName = arr.join ""

		_shortedLinks[shortName] =
			long: long
			clicks: 0

		_saveShortedLinks()

	return shortName

getShorted = (short) ->
	unless _shortedLinks[short]? then return null

	_shortedLinks[short].clicks++
	_saveShortedLinks()
	return _shortedLinks[short].long

app.get "/", (req, res) ->
	fs.readdir "./posts", (e, files) ->
		if e? then onError e, req, res
		else
			files = _.filter files, (f) ->
				splitted = f.split "."
				return splitted[splitted.length - 1] is "md"

			_.map files, ((file, cb) ->
				fs.readFile "./posts/#{file}", (e, r) ->
					cb e,
						title: file.split(".")[0]
						creation: new Date((""+r).split("\n")[0]).toISOString().substring 0, 10
			), (e, r) ->
				if e? then onError e, req, res
				else res.render "index", posts: r

app.get "/me", (req, res) ->
	res.render "me", { nowPlaying, githubDate, lastGame, keys, clicks }

app.get "/post/:post", (req, res) ->
	name = unescape req.params.post
	path = "./posts/#{name}.md"

	fs.readFile path, (e, data) ->
		unless e?
			splitted = ("" + data).split("\n")
			res.render "post",
				title: name
				content: marked "" + splitted[1..].join("\n")
				creation: new Date(splitted[0]).toISOString().substring 0, 10

		else if e.code is "ENOENT"
			res.status(404).render "404"

		else onError e, req, res

app.get "/projects", (req, res) ->
	res.render "projects"

app.get "/resume", (req, res) ->
	res.render "resume"

app.post "/short", (req, res) ->
	s = ""
	req.on "data", (blob) -> s += blob
	req.on "end", ->
		try
			res.status(201).end "http://www.lieuwex.me/#{setShorted s}"
		catch e
			res.status(500).end e.toString()

app.get "/golocal/:port?", (req, res) ->
	url = "http://#{IP}"
	if (port = req.params.port)? then url += ":#{port}"
	res.redirect url
app.get "/local", (req, res) -> res.end IP

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
