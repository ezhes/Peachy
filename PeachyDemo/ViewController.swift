//
//  ViewController.swift
//  Peachy
//
//  Created by Salman Husain on 2/7/19.
//  Copyright © 2019 Salman Husain. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        //Create a session. Unauthenticated by default, an error will be returned if you attempt any operation except authenticate before succesfully authenticating
        let session:PeachAPISession = PeachAPISession.init()
        session.authenticate(username: "<username>", password: "<password>") { (loginResult) in
            switch loginResult {
            case .failure(let error):
                //Handle failures correctly
                print(error)
            case .success( _):
                print("Authenticated!")

                //We're now authenticated. State is handled by the session object so we don't need to do anything else. Let's now call our method to print some inteesting data out.
                self.printAllFriendsAndMostRecentPost(session: session)
            }
        }
    }
    
    func printAllFriendsAndMostRecentPost(session:PeachAPISession) {
        session.getConnections { (result) in
            switch result {
            case .failure(let error):
                print(error)
            case .success(let response):
                //The connections end point returns a lot more data than just the connections data. Explore this object, there's a lot.
                for stream in response.connections {
                    //stream is a PeachStream object. Again, it's a great idea to add a break point here and explore the data held within

                    var lastPostTextRepresentation = ""
                    //Many of the data types returned by peach are reused just with slightly more (or less) data attached. Optionals are heavily used to make handling this data availbility easy. Generally, using the most specific API end point will return the most filled out data structure.
                    if let lastPost = stream.posts?.last {
                        //Peach structures posts in "messages". Regular, pure text posts have just one (type = "text") but complex ones with GIFs, photos, and videos will have multiple messages
                        for message in lastPost.message {
                            //Peach returns a few different message types. A few examples include text, link, GIF, video, music, location. These different types are not handled but instead left up to you.
                            let messageType = message.type
                            
                            //Here we're just going to make a really simple handler which only works with text, image, and link.
                            switch messageType {
                            case "text":
                                lastPostTextRepresentation += "\(message.getText() ?? "<no text>")\n"
                            case "image":
                                lastPostTextRepresentation += "[Image: \(message.getURL() ?? "<no url>")]\n"
                            case "link":
                                lastPostTextRepresentation += "[Link, URL: \(message.getURL() ?? "<no url>"), text:\(message.getText() ?? "<no text>")]\n"
                            default:
                                print("unexpected message type \(messageType), ignoring!")
                            }
                        }
                    }
                    
                    print("[\(stream.name ?? "<no username>")] \(lastPostTextRepresentation)")
                }
            }
        }
    }


}

