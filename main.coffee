_ = require "nimble"
express = require "express"
compress = require "compression"
minify = require "express-minify"
fs = require "fs"
lastfm = require("lastfm").LastFmNode
github = require("github")
marked = new require("marked")
nowPlaying = null

app = express()
#io = require('socket.io')(require("http").createServer app)
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

app.get "/", (req, res) ->
	fs.readdir "./posts", (e, files) ->
		if e? then onError e, req, res
		else
			files = _.filter files, (f) ->
				splitted = f.split "."
				return splitted[splitted.length - 1] is "md"

			_.map files, ((file, cb) ->
				fs.stat "./posts/#{file}", (e, r) ->
					cb e,
						title: file.split(".")[0]
						creation: r.ctime.toISOString().substring 0, 10
			), (e, r) ->
				if e? then onError e, req, res
				else res.render "index", posts: r

app.get "/me", (req, res) ->
	res.render "me", { nowPlaying, githubDate }

app.get "/post/:post", (req, res) ->
	name = unescape req.params.post
	path = "./posts/#{name}.md"

	fs.readFile path, (e, data) ->
		unless e?
			fs.stat path, (e, stats) ->
				if e? onError e, req, res
				else
					res.render "post",
						title: name
						content: marked "" + data
						creation: stats.ctime.toISOString().substring 0, 10

		else if e.code is "ENOENT"
			res.status(404).render "404"

		else onError e, req, res

app.get "/projects", (req, res) ->
	res.render "projects"

app.get "*", (req, res) ->
	res.status(404).render "404"

app.listen 1337