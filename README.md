# Peachy

A no dependency API client for [Peach](https://peach.cool) written in Swift


## API Coverage

This library was created by reverse engineering the network requests of the native Peach app on iOS. For this reason, I cannot give any guarantees that all API methods are implemented fully (or correctly). Below is a list of all of the (high level) scopes I have attempted to implement.

* Streams: retrieving your own and others', marking as read
* Comments: retrieving your own and others', posting comments, and deleting comments
* Posts: retrieving, liking, posting, and deleting
* Activity: retrieving the activity stream (likes, replies, etc) and marking as read
* Friend management: add friends, delete friends, accept friends
* User information: retrieving display name, posts, bio, avatar, friend list, and streams by username


## Using it

1. Drag and drop all the files in from `/Peachy_API_Client` into your project. 
2. Create a `PeachAPISession` object using `PeachAPISession.init()`.
3. Call `<your_session>.authenticate` with a username or password or restore login state using externally cached tokens using `<your_session>.status = .authenticated(loginData: LoginData.init(...))`


At this point you should be ready to make any API calls you want against the Peach API. 

If you're more of a "learn by example" person, check out `PeachyDemo/ViewController.swift` for a quick run down on authentication and interacting with the user streams.