//
//  Session.swift
//  Pit
//
//  Created by Salman Husain on 1/21/19.
//  Copyright © 2019 Salman Husain. All rights reserved.
//

import Foundation


/*
 cursor? some sort of pagination?? we need this because we have so many friends
 
 */


/// List of PeachyAPI error codes
///
/// - UnsupportedStateError: The function called cannot be executed in a session with the given state. Are you authenticated?
/// - PeachAPIError: Peach returned an error code. Check the error `NSLocalizedDescriptionKey` for more info as to the specific failure
/// - NoDataReturnedError: No data was returned from the endpoint however some was expected. This is generally an internal API error and cannot be caused by something you did.
public enum PeachErrors:Int {
    case UnsupportedStateError
    case PeachAPIError
    case NoDataReturnedError
}


/// The authentication state of the session
///
/// - unauthenticated: (default) No credentials have been provided
/// - error: Authentication failed for some reason (network, bad password)
/// - authenticated: The session is ready and authenticated
enum SessionStatus {
    case unauthenticated
    case error
    case authenticated(loginData:LoginData)
}

private struct ErrorConstants {
    static let alreadyAuthenticatedUserInfo = [NSLocalizedDescriptionKey:" Unsuported state, attempted to authenticate when already authenticated"]
    static let authenticationUserInfo = [NSLocalizedDescriptionKey:"Unsuported state, attempted to use an authenticated query when not signed in"]
}


/// A callback result
///
/// - success: Holds the returned data
/// - failure: Holds an error response
public enum Result<A> {
    case success(A)
    case failure(NSError)
    
    public init(value: A) {
        self = .success(value)
    }
    
    public init(fromOptional: A?, error: NSError) {
        if let value = fromOptional {
            self = .success(value)
        } else {
            self = .failure(error)
        }
    }
    
    public init(from: A, optional error: NSError?) {
        if let error = error {
            self = .failure(error)
        } else {
            self = .success(from )
        }
    }
    
    public var error: NSError? {
        switch self {
        case .failure(let error):
            return error
        default:
            return nil
        }
    }
    
    public var value: A? {
        switch self {
        case .success(let success):
            return success
        default:
            return nil
        }
    }
}


/// Peach API session
class PeachAPISession {
    var status:SessionStatus = .unauthenticated
    var urlSession = URLSession(configuration: URLSessionConfiguration.default)
    
    let jsonEncoder = JSONEncoder.init()
    let jsonDecoder = JSONDecoder.init()
    
    
    /// Authenticate with a peach username and password
    public func authenticate(username:String,password:String,completion: @escaping ((Result<SessionStatus>) -> Void)) {
        //Only allow this in the error state
        switch status {
        case .unauthenticated, .error:
            break;
        default:
            completion(Result.init(fromOptional: nil, error: NSError.init(domain: "PeachAPI", code: PeachErrors.UnsupportedStateError.rawValue, userInfo: ErrorConstants.alreadyAuthenticatedUserInfo)))
            return
        }
        
        let httpBody:[String:String] = ["email":username,"password":password]

        let apiCompletion:((Result<LoginData>) -> Void) = {
            result in
            switch result {
            case .failure(let error):
                completion(Result.init(fromOptional: nil, error: error))
            case .success(let loginData):
                self.status = .authenticated(loginData: loginData)
                completion(Result.init(value: self.status))
            }
        }
        makeAPICall(path: "login", method: "POST", postData: httpBody, completion: apiCompletion)
    }
    
    /// Get the "connections" data. This is the /connections end point which returns a HUGE batch of initial data which includes every one of the user's friends' streams (without comments) and all friend requests. This data can, at worst, be up to 3MB so be careful hitting this often.
    public func getConnections(completion: @escaping ((Result<Connections>) -> Void)) {
        //Only allow this in the authenticated state
        switch status {
        case .authenticated(_ ):
            break;
        default:
            completion(Result.init(fromOptional: nil, error: NSError.init(domain: "PeachAPI", code: PeachErrors.UnsupportedStateError.rawValue, userInfo: ErrorConstants.authenticationUserInfo)))
            return
        }
        
        makeAPICall(path: "connections", method: "GET", postData: [:], completion: completion)
    }
    
    
    /// Get the data of one stream specifically. This request, unliked `getConnections` does return comments for each post
    public func getStream(streamID:String,completion: @escaping ((Result<PeachStream>) -> Void)) {
        switch status {
        case .authenticated(_ ):
            break;
        default:
            completion(Result.init(fromOptional: nil, error: NSError.init(domain: "PeachAPI", code: PeachErrors.UnsupportedStateError.rawValue, userInfo: ErrorConstants.authenticationUserInfo)))
            return
        }
        
        makeAPICall(path: "stream/id/\(streamID)", method: "GET", postData: [:], completion: completion)
    }
    
    /// Get a single post, useful for handling links and viewing posts from the activity stream
    public func getPost(postID:String,completion: @escaping ((Result<PeachStream>) -> Void)) {
        switch status {
        case .authenticated(_ ):
            break;
        default:
            completion(Result.init(fromOptional: nil, error: NSError.init(domain: "PeachAPI", code: PeachErrors.UnsupportedStateError.rawValue, userInfo: ErrorConstants.authenticationUserInfo)))
            return
        }
        
        makeAPICall(path: "post/\(postID)", method: "GET", postData: [:], completion: completion)
    }
    
    /// Get the activity stream. This includes data such as likes, comment replies, and other stuff that's in the right most panel in the 1st party app
    public func getActivity(completion: @escaping ((Result<ActivityStream>) -> Void)) {
        switch status {
        case .authenticated(_ ):
            break;
        default:
            completion(Result.init(fromOptional: nil, error: NSError.init(domain: "PeachAPI", code: PeachErrors.UnsupportedStateError.rawValue, userInfo: ErrorConstants.authenticationUserInfo)))
            return
        }
        
        makeAPICall(path: "activity", method: "GET", postData: [:], completion: completion)
    }
    
    /// Mark the activity stream contents as read, thus setting the `ActivityStream.unreadActivityItemCount` to zero
    public func markActivityStreamRead(completion: @escaping ((Result<EmptySuccess>) -> Void)) {
        switch status {
        case .authenticated(_ ):
            break;
        default:
            completion(Result.init(fromOptional: nil, error: NSError.init(domain: "PeachAPI", code: PeachErrors.UnsupportedStateError.rawValue, userInfo: ErrorConstants.authenticationUserInfo)))
            return
        }
        
        makeAPICall(path: "activity/read", method: "PUT", postData: [:], fakeSuccessObject: EmptySuccess.init(), completion: completion)
    }
    
    /// Mark a user stream as read (removes the green dot in the 1st party app, sets `PeachStream.unreadPostCount` to zero)
    public func markStreamRead(streamID:String, completion: @escaping ((Result<EmptySuccess>) -> Void)) {
        switch status {
        case .authenticated(_ ):
            break;
        default:
            completion(Result.init(fromOptional: nil, error: NSError.init(domain: "PeachAPI", code: PeachErrors.UnsupportedStateError.rawValue, userInfo: ErrorConstants.authenticationUserInfo)))
            return
        }
        
        makeAPICall(path: "stream/id/\(streamID)/read", method: "PUT", postData: [:], fakeSuccessObject: EmptySuccess.init(), completion: completion)
    }
    
    
    /// Set a post's like status
    ///
    /// - Parameters:
    ///   - postID: The post ID
    ///   - liked: true for liked, false for unliked
    public func setLiked(postID:String, liked:Bool, completion: @escaping ((Result<EmptySuccess>) -> Void)) {
        if liked {
            like(postID: postID, completion: completion)
        }else {
            unlike(postID: postID, completion: completion)
        }
    }
    
    private func like(postID:String, completion: @escaping ((Result<EmptySuccess>) -> Void)) {
        switch status {
        case .authenticated(_ ):
            break;
        default:
            completion(Result.init(fromOptional: nil, error: NSError.init(domain: "PeachAPI", code: PeachErrors.UnsupportedStateError.rawValue, userInfo: ErrorConstants.authenticationUserInfo)))
            return
        }
        
        makeAPICall(path: "like", method: "POST", postData: ["postId":postID], fakeSuccessObject: EmptySuccess.init(), completion: completion)
    }

    private func unlike(postID:String, completion: @escaping ((Result<EmptySuccess>) -> Void)) {
        switch status {
        case .authenticated(_ ):
            break;
        default:
            completion(Result.init(fromOptional: nil, error: NSError.init(domain: "PeachAPI", code: PeachErrors.UnsupportedStateError.rawValue, userInfo: ErrorConstants.authenticationUserInfo)))
            return
        }
        
        makeAPICall(path: "like/postID/\(postID)", method: "DELETE", postData: [:], fakeSuccessObject: EmptySuccess.init(), completion: completion)
    }
    
    /// Delete a given post. This is only supposed to work against your own stream but who knows
    public func deletePost(postID:String, completion: @escaping ((Result<EmptySuccess>) -> Void)) {
        switch status {
        case .authenticated(_ ):
            break;
        default:
            completion(Result.init(fromOptional: nil, error: NSError.init(domain: "PeachAPI", code: PeachErrors.UnsupportedStateError.rawValue, userInfo: ErrorConstants.authenticationUserInfo)))
            return
        }
        
        makeAPICall(path: "post/\(postID)", method: "DELETE", postData: [:], fakeSuccessObject: EmptySuccess.init(), completion: completion)
    }
    
    
    /// Post to your own stream
    ///
    /// - Parameters:
    ///   - messages: An array of messages. You can create these synthentically using `message.init(...)`. Sort of a pain since there are many different properties depending on the exact type. Check out the code for the Message class for a tiny bit of help finding out the specific fields that need to be set for each type
    public func post(messages:[Message],completion: @escaping ((Result<Post>) -> Void)) {
        switch status {
        case .authenticated(_ ):
            break;
        default:
            completion(Result.init(fromOptional: nil, error: NSError.init(domain: "PeachAPI", code: PeachErrors.UnsupportedStateError.rawValue, userInfo: ErrorConstants.authenticationUserInfo)))
            return
        }
        
        let body = ["message":messages]
        let data = try! jsonEncoder.encode(body)
        makeAPICall(path: "post", method: "POST", data: data, completion: completion)
    }
    

    /// Request a user as a friend
    public func requestFriend(username:String, completion: @escaping ((Result<NewFriendRequestResponse>) -> Void)) {
        switch status {
        case .authenticated(_ ):
            break;
        default:
            completion(Result.init(fromOptional: nil, error: NSError.init(domain: "PeachAPI", code: PeachErrors.UnsupportedStateError.rawValue, userInfo: ErrorConstants.authenticationUserInfo)))
            return
        }
        
        makeAPICall(path: "stream/n/\(username)/connection", method: "POST", completion: completion)
    }
    
    /// Delete a friend request. This, for whatever reason, does not use the same requestID as returned by `requestFriend` but instead the one returned by `getConnections`'s outbound friend requests. Not sure why, but this does work when you use the latter value.
    public func deleteFriendRequest(requesetID:String, completion: @escaping ((Result<EmptySuccess>) -> Void)) {
        switch status {
        case .authenticated(_ ):
            break;
        default:
            completion(Result.init(fromOptional: nil, error: NSError.init(domain: "PeachAPI", code: PeachErrors.UnsupportedStateError.rawValue, userInfo: ErrorConstants.authenticationUserInfo)))
            return
        }
        
        makeAPICall(path: "friend-request/\(requesetID)", method: "DELETE",  fakeSuccessObject: EmptySuccess.init(), completion: completion)
    }
    
    /// Remove a friend by their streamID
    public func deleteFriend(streamID:String, completion: @escaping ((Result<EmptySuccess>) -> Void)) {
        switch status {
        case .authenticated(_ ):
            break;
        default:
            completion(Result.init(fromOptional: nil, error: NSError.init(domain: "PeachAPI", code: PeachErrors.UnsupportedStateError.rawValue, userInfo: ErrorConstants.authenticationUserInfo)))
            return
        }
        
        makeAPICall(path: "stream/id/\(streamID)/connection", method: "DELETE",  fakeSuccessObject: EmptySuccess.init(), completion: completion)
    }
    
    /// Accept a friend request. This, for whatever reason, does not use the same requestID as returned by `requestFriend` but instead the one returned by `getConnections`'s inbound friend requests. Not sure why, but this does work when you use the latter value.
    public func acceptFriendRequest(requesetID:String, completion: @escaping ((Result<EmptySuccess>) -> Void)) {
        switch status {
        case .authenticated(_ ):
            break;
        default:
            completion(Result.init(fromOptional: nil, error: NSError.init(domain: "PeachAPI", code: PeachErrors.UnsupportedStateError.rawValue, userInfo: ErrorConstants.authenticationUserInfo)))
            return
        }
        
        makeAPICall(path: "friend-request/\(requesetID)/accept", method: "POST",  fakeSuccessObject: EmptySuccess.init(), completion: completion)
    }
    
    
    /// Post a comment
    ///
    /// - Parameters:
    ///   - comment: A filled comment object. Use `Comment.init` to provide both the body and postID
    public func post(comment:Comment,completion: @escaping ((Result<Comment>) -> Void)) {
        switch status {
        case .authenticated(_ ):
            break;
        default:
            completion(Result.init(fromOptional: nil, error: NSError.init(domain: "PeachAPI", code: PeachErrors.UnsupportedStateError.rawValue, userInfo: ErrorConstants.authenticationUserInfo)))
            return
        }
        
        let data = try! jsonEncoder.encode(comment)
        makeAPICall(path: "comment", method: "POST", data: data, completion: completion)
    }
    
    /// Delete a comment. This works against your own comments on any stream as well as any comment on your own stream (in other words, you can always delete your comments but you can also delete other peoples' on your own posts)
    public func deleteComment(commentID:String, completion: @escaping ((Result<EmptySuccess>) -> Void)) {
        switch status {
        case .authenticated(_ ):
            break;
        default:
            completion(Result.init(fromOptional: nil, error: NSError.init(domain: "PeachAPI", code: PeachErrors.UnsupportedStateError.rawValue, userInfo: ErrorConstants.authenticationUserInfo)))
            return
        }
        
        makeAPICall(path: "comment/\(commentID)", method: "DELETE", postData: [:], fakeSuccessObject: EmptySuccess.init(), completion: completion)
    }
    
    /// Get the user's friends list
    public func getFriendsList(username:String, completion: @escaping ((Result<FriendsList>) -> Void)) {
        switch status {
        case .authenticated(_ ):
            break;
        default:
            completion(Result.init(fromOptional: nil, error: NSError.init(domain: "PeachAPI", code: PeachErrors.UnsupportedStateError.rawValue, userInfo: ErrorConstants.authenticationUserInfo)))
            return
        }
        
        makeAPICall(path: "stream/n/\(username)/connections", method: "GET", completion: completion)
    }
    
    //MARK: Network
    
    
    /// Make an API request to peach, adding bearer tokens automatically from the state object
    ///
    /// - Parameters:
    ///   - path: The path (with no prepended slash. i.e. "activity/read")
    ///   - method: HTTP method ("GET", "PUT", etc)
    ///   - data: Raw data to attach as the HTTP body
    ///   - postData: The HTTP body to be encoded to JSON
    ///   - fakeSuccessObject: If this API request returns just {"success" : 1}, provide a precreated object to this function to be returned on success. This is hacky and bad but it's just a small hack so I can use the Result arch.
    ///   - completion: A callback which takes the Result
    private func makeAPICall<ExpectedPayloadType:Codable>(path:String,method:String,data:Data? = nil,postData:[String:String]? = nil,fakeSuccessObject:ExpectedPayloadType? = nil,completion: @escaping ((Result<ExpectedPayloadType>) -> Void)) {
        var urlRequest = URLRequest.init(url: URL.init(string: "https://v1.peachapi.com/\(path)")!)
        urlRequest.httpMethod = method
        
        if postData?.count ?? -1 > 0 {
            let httpBodyData = try! jsonEncoder.encode(postData!)
            urlRequest.httpBody = httpBodyData
        }else if let data = data {
            urlRequest.httpBody = data
        }
        
        switch status {
        case .authenticated(let loginData):
            urlRequest.addValue("Bearer \(loginData.streams.first!.token)", forHTTPHeaderField: "Authorization")
        default:
            break;
        }
        
        executeTask(urlRequest, handleResponse: { (responseData, urlResponse, error) -> Result<ExpectedPayloadType> in
            var result:Result<ExpectedPayloadType>? = nil
            if let error = error {
                result = Result.init(fromOptional: nil, error: error)
            }else {
                do {
                    let decodedWrapped = try JSONDecoder.init().decode(APIMessage<ExpectedPayloadType>.self, from: responseData!)
                    if let peachError = decodedWrapped.error {
                        result = Result.init(fromOptional: nil, error: peachError.toNSError())
                    }else {
                        if let data = decodedWrapped.data {
                            result = Result.init(value: data)
                        }else {
                            if let fakeObject = fakeSuccessObject {
                                result = Result.init(value: fakeObject)
                            }else {
                                //No data, fill with a "No data error" as the consumer should know that there's no data
                                result = Result.init(fromOptional: nil, error: NSError.init(domain: "PeachAPI", code: PeachErrors.NoDataReturnedError.rawValue, userInfo: [NSLocalizedDescriptionKey:"No data was returned by the API. This is not an error if you were expecting this to happen"]))

                            }
                        }
                    }
                }catch {
                    result = Result.init(fromOptional: nil, error: error as NSError)
                }
            }
            
            return result!
        }) { (result) in
            completion(result)
        }
    }
    
    
    /// Execute a URL request
    @discardableResult
    private func executeTask<T>(_ request: URLRequest, handleResponse: @escaping ((_ data: Data?, _ response: URLResponse?, _ error: NSError?) -> Result<T>), completion: @escaping ((Result<T>) -> Void)) -> URLSessionDataTask {
        
        
        let task = urlSession.dataTask(with: request, completionHandler: { (data: Data?, response: URLResponse?, error: Error?) -> Void in
            let result = handleResponse(data, response, error as NSError?)
            completion(result)
        })
        task.resume()
        return task
    }
}
