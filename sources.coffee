request = require 'request'
github = require 'github'
lastfm = require('lastfm').LastFmNode

class Source
	constructor: (@name, @onEnable, @options = {}) ->
		@_intervalId = undefined
		@_lastResult = undefined

	enable: ->
		return if @_intervalId? # already enabled
		fn = =>
			@onEnable (err, res) =>
				if err?
					console.error "error while fetching data from #{@name}", err
				else
					@_lastResult = res
					@_update?()

		if @options.interval?
			@_intervalId = setInterval fn, @options.interval
		fn()

	disable: ->
		clearInterval @_intervalId
		@_intervalId = undefined
		@onDisable?()

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
	request.get 'http://api.whatpulse.org/user.php?user=lieuwex&format=json&formatted=yes', (err, resp, body) ->
		if e?
			cb e, null
			return

		parsed = null
		try parsed = JSON.parse(body)
		catch e then cb e, null

		cb null,
			keys: parsed.Keys
			clicks: parsed.Clicks

mksrc 'typeracer', minutes(60), (cb) ->
	request.get 'http://typeracerdata.appspot.com/users?id=tr:lieuwex', (err, resp, body) ->
		if e?
			cb e, null
			return

		parsed = null
		try parsed = JSON.parse body
		catch e then cb e, null

		cb null,
			bestwpm:    Math.round parsed.tstats.bestGameWpm
			averagewpm: Math.round parsed.tstats.recentAvgWpm

githubClient = new github version: '3.0.0'
mksrc 'github', minutes(20), (cb) ->
	githubClient.events.getFromUser { user: 'lieuwex' }, (e, r) ->
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
