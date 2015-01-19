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
trackStream.start()

githubDate = null
gh = -> githubClient.events.getFromUser { user: "lieuwex" }, (e, r) -> unless e? then githubDate = r[0].created_at.substring 0, 10
gh(); setInterval gh, 600000

lastGame = null
league = ->
	request.get "https://euw.api.pvp.net/api/lol/euw/v1.3/game/by-summoner/49307699/recent?api_key=647ce360-313e-4f15-92e9-fef71803ab79", (err, resp, body) ->
		return if e?
		lastGame = JSON.parse(body).games[0]
		champId = lastGame.championId

		if lastGame.subType.indexOf("RANKED_") isnt -1 # LoL Matchhistory is usable on ranked games and is way nicer than LoLKing.
			lastGame.url = "http://matchhistory.euw.leagueoflegends.com/en/#match-details/EUW1/#{lastGame.gameId}/41989123"
		else # Normal games on LoL matchhistory are only visible for the players of the match. Use LoLKing instead.
			lastGame.url = "http://www.lolking.net/summoner/euw/49307699#matches/#{lastGame.gameId}"

		request.get "https://global.api.pvp.net/api/lol/static-data/euw/v1.2/champion/#{champId}?api_key=647ce360-313e-4f15-92e9-fef71803ab79", (err, resp, body) ->
			lastGame.champName = JSON.parse(body).name

league(); setInterval league, 300000

fs.mkdirSync("./posts") unless fs.existsSync "./posts"

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
	res.render "me", { nowPlaying, githubDate, lastGame }

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

app.get "*", (req, res) ->
	res.status(404).render "404"

port = process.env.PORT || 5000
app.listen port, -> console.log "Running on port #{port}"
