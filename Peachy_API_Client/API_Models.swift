//
//  API_Models.swift
//  Pit
//
//  Created by Salman Husain on 2/3/19.
//  Copyright © 2019 Salman Husain. All rights reserved.
//

import Foundation

class APIError:Codable {
    let Code:Int
    let Message:String
    
    public func toNSError() -> NSError {
        return NSError.init(domain: "PeachAPI", code: PeachErrors.PeachAPIError.rawValue, userInfo: [NSLocalizedDescriptionKey:"[\(Code)] \(Message)"])
    }
}

class APIMessage<CodableType:Codable>:Codable {
    let success:Int
    let error:APIError?
    let data:CodableType?
    
}

class LoginData:Codable {
    /// WARNING THIS IS NOT THE TOKEN YOU NEED FOR AUTHENTICATED REQUESTS!! SEE `.streams`
    let token:String
    let streams:[AuthenticationPeachStream]
    
    init(token inToken:String,streams inStream:[AuthenticationPeachStream]) {
        token = inToken
        streams = inStream
    }
}

/// This is the actually important part of authentication. These tokens are bound into every request
class AuthenticationPeachStream:Codable {
    let id:String
    let token:String
    
    init(id inId:String, token inToken:String) {
        id = inId
        token = inToken
    }
}

class Connections:Codable {
    let connections:[PeachStream]
    let inboundFriendRequests:[FriendRequest]
    let outboundFriendRequests:[FriendRequest]
    let requesterStream:PeachStream
}

class PeachStream:Codable {
    let id:String?
    let name:String?
    let displayName:String?
    let avatarSrc:String?
    let bio:String?
    let isPublic:Bool?
    let friendsSharing:Bool?
    let posts:[Post]?
    let unreadPostCount:Int?
    let lastRead:Int?
    let isFavorite:Bool?
    let youFollow:Bool?
    let followsYou:Bool?
    let cursor:String?
}

class Post:Codable {
    let id:String
    let message:[Message]
    let commentCount:Int
    let likeCount:Int
    let comments:[Comment]?
    let likedByMe:Bool
    let isUnread:Bool
    let createdTime:Int?
    let updatedTime:Int?
}

class Message:Codable {
    var type:String
    
    //type = image
    var src:String?
    
    //type = link
    var title:String?
    var url:String?
    
    //type = text
    var text:String?
    /// The attributes used for special formatting of type = text posts
    var attributes:[TextAttribute]?
    
    init(type typeIn:String) {
        type = typeIn
    }
    
    
    /// Get the user visible text component of the message. This applies to type = text,link
    ///
    /// - Returns: The text, if there is any.
    public func getText() -> String? {
        return text != nil ? text : title
    }
    
    
    /// Get the URL associated with the message. This applies to GIFs, images, links, videos, and probably some others
    ///
    /// - Returns: The URL string, if there is any
    public func getURL() -> String? {
        return url != nil ? url : src
    }
}

class TextAttribute:Codable {
    let range:[Int]
    let type:String
}

class Comment:Codable {
    //When retriving these are set
    let id:String?
    let author:PeachStream?

    //When creating these are set
    private let postId:String?
    
    //wtf peach, so somebody made a typo so we have keys "postId" and "postID" and so we need both. fuck.
    private let postID:String?
    
    public func getPostID() -> String? {
        return postId != nil ? postId : postID
    }
    
    let body:String
    
    init(body inBody:String, postId inPostId:String) {
        body = inBody
        postId = inPostId
        postID = inPostId
        
        id = nil
        author = nil
    }
}

class FriendRequest:Codable {
    let id:String
    let stream:PeachStream
    let createdTime:Int
}

class NewFriendRequestResponse:Codable {
    let id:String
    let status:String
    let stream:PeachStream
}

class ActivityStream:Codable {
    let streamID:String
    let unreadActivityItemCount:Int
    let lastRead:Int
    let activityItems:[ActivityItem]
}

class ActivityItem:Codable {
    let type:String
    let isUnread:Bool
    let createdTime:Int
    let body:ActivityBody
}

class ActivityBody:Codable {
    let postID:String
    let authorStream:PeachStream
    let postMessage:[Message]
    
    /// Used when ActivityItem.type = comment || mention
    let commentBody:String?
    
    /// Used when ActivityItem.type = mention
    let postAuthorStream:PeachStream?
}


class FriendsList:Codable {
    let connections:[PeachStream]
}


/// A boolean return state, used by operations which do not return data.
class EmptySuccess:Codable {}
