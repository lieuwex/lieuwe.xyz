2015-08-23
One of the things that makes Meteor so great is the
[hot code push](https://meteor.hackpad.com/Hot-Code-Push-design-notes-9o22fy6gruu)
feature, in case you don't know it; it reloads your Meteor app when you change
your code, while storing some data, data stored with the `Session` package, for
example.

This feature is amazing, it's a perfect fit for continuous integration.
You want to update your app with fixes and new features ASAP, but you don't want
to bother the users when they were changing state in your application. Meteor
handles that.

This sounds great, but saving the state of the application doesn't really work
that well in practice, all the data that needs to be migrated between reloads
has to be JSON serializable (it gets saved in local storage), and the code that
you use to store the data will need to handle the reload stuff (you can't use
normal variables).

So, wouldn't it be great if we could have a quick reload cycle, but not
reloading the app all of the sudden, with the possibility of losing data?
Spotify has a good solution for this:

![](/spotify-update-bar.jpg)

I wanted to have the same kind of thing for
[simplyHomework](http://www.simplyHomework.nl). Remember that I said that
packages need to handle reloads to store data? Meteor has a function
`Reload._onMigrate` which requires a function as parameter, which can give the
data back to store, if it has any. It can also postpone the reload if it still
has to handle storing data.

We can 'abuse' this system to only let the app reload if the user gave
permission to do so. Without providing any data. Which is exactly what we do,
so for the code:

```javascript
var canReload = false;
var notice;

Reload._onMigrate('lazy-code-push', function (retry) {
	// If we didn't ask the user yet if they want to reload, ask.
	// We only want to ask once, even if the user answered no.
	if (notice === undefined) {
		notice = setBigNotice({
			content: 'simplyHomework is geüpdatet! Klik hier om de pagina te herladen.',
			onClick: function () {
				notice.hide();
				canReload = true;
				retry();
			},
		});
	}
	return [canReload];
});
```

We have a function `setBigNotice` which shows a bar with the given `content`, if
it's clicked it will call `onClick`, which allows the app to reload. It looks
like this:

![](/simplyHomework-update-bar.png)

Success! The user can continue using the app, and when he's ready, he can let
the app reload.
