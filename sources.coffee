fetch = require 'node-fetch'
github = require 'github'
lastfm = require('lastfm').LastFmNode

class Source
	constructor: (@name, @onEnable, @options = {}) ->
		@enabled = no
		@_intervalId = undefined
		@_lastResult = undefined

	enable: ->
		return if @enabled
		console.log "enabling service '#{@name}'"
		fn = =>
			console.log "running service '#{@name}'"
			@onEnable (err, res) =>
				if err?
					console.error "error while fetching data from service '#{@name}'", err
				else
					@_lastResult = res
					@_update?()

		if @options.interval?
			@_intervalId = setInterval fn, @options.interval
		fn()

		@enabled = yes
		undefined

	disable: ->
		return unless @enabled
		console.log "disabling service '#{@name}'"
		clearInterval @_intervalId
		@_intervalId = undefined
		@onDisable?()
		@enabled = no
		undefined

class Sources
	@_sources: {}
	@_callbacks: []

	@addSource: (source) ->
		name = source.name

		if @_sources[name]?
			throw new Error "already a source with '#{name}' as name"

		source._update = =>
			for cb in @_callbacks
				cb name, source._lastResult

		@_sources[name] = source

	@getLastData: (name) ->
		@_sources[name]._lastResult

	@onData: (fn) ->
		@_callbacks.push fn

module.exports = { Sources, Source }

mksrc = (name, interval, fn) ->
	source = new Source name, fn, { interval }
	Sources.addSource source
	source.enable()

# converts minutes to milliseconds.
minutes = (val) -> val * 60 * 1000

mksrc 'whatpulse', minutes(120), (cb) ->
	fetch('http://api.whatpulse.org/user.php?user=lieuwex&format=json&formatted=yes')
		.then (res) -> res.json()
		.catch (e) -> cb e, null
		.then (res) ->
			cb null,
				keys: res.Keys
				clicks: res.Clicks

mksrc 'typeracer', minutes(60), (cb) ->
	fetch('http://typeracerdata.appspot.com/users?id=tr:lieuwex')
		.then (res) -> res.json()
		.catch (e) -> cb e, null
		.then (res) ->
			cb null,
				bestwpm:    Math.round res.tstats.bestGameWpm
				averagewpm: Math.round res.tstats.recentAvgWpm

githubClient = new github version: '3.0.0'
mksrc 'github', minutes(20), (cb) ->
	githubClient.activity.getEventsForUser {
		user: 'lieuwex'
		page: 1
		per_page: 1
	}, (e, r) ->
		if e? then cb e, null
		else cb null, r[0].created_at.substring 0, 10

lastfmClient = new lastfm
	'api_key': 'b68ffcb32c581066eff2eaa6443252d4'
	'secret': '92273fdb7205a5800f44555ddd6cc162'
trackStream = lastfmClient.stream 'lieuwex'

lastfm = new Source 'lastfm', (cb) ->
	trackStream.on 'nowPlaying', (track) -> cb null, track
	trackStream.on 'stoppedPlaying', -> cb null, null
	trackStream.on 'error', (e) -> cb e, null
	trackStream.start()
lastfm.onDisable = -> trackStream.stop()
Sources.addSource lastfm
lastfm.enable()
