rss = require 'rss-generator'

module.exports = (posts) ->
	feed = new rss
		title: 'Lieuwe Rooijakkers'
		description: 'Lieuwe Rooijakkers\' Blog. Web front- and back-end developer.'
		feed_url: 'https://lieuwe.xyz/rss'
		site_url: 'https://lieuwe.xyz/'
		language: 'en_US'

	for post in posts
		feed.item
			title: post.title
			description: post.content
			date: post.creation
			url: "https://lieuwe.xyz/post/#{post.title}"

	feed.xml()
