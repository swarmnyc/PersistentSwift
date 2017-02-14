//
//  Service.swift
//  Pods
//
//  Created by Alex Hartwell on 2/9/17.
//
//

import Foundation
import Moya
import PromiseKit
import Alamofire

open class PSServiceManager {

	static var constants = ServiceConstants(baseUrl: "");
	static var authToken: String?
	static var isTesting: Bool = false;

	open static func setBaseUrl(_ url: String) {
		PSServiceManager.constants.baseUrl = url;
	}

	open static func setAuthToken(token: String) {
		PSServiceManager.authToken = token;
	}

	open static func setIsTesting(_ bool: Bool) {
		self.isTesting = bool;
	}

}

/// Extend default Manager to support timeout
class DefaultAlamofireManager: Alamofire.SessionManager {

	/// Get a shared Manager with timeout
	static func sharedManager(_ timeout: TimeInterval) -> DefaultAlamofireManager {
		let configuration = URLSessionConfiguration.default
		configuration.httpAdditionalHeaders = Alamofire.SessionManager.defaultHTTPHeaders
		configuration.timeoutIntervalForRequest = timeout // as seconds, you can set your requesttimeout
		configuration.timeoutIntervalForResource = timeout // as seconds, you can set your resource timeout
		configuration.requestCachePolicy = .useProtocolCachePolicy
		return DefaultAlamofireManager(configuration: configuration)
	}
}


public struct TimeoutPlugin<T:PSCachedModel, D:TestData>: PluginType {
    
    var timeoutGetter: ((PSServiceMap<T,D>) -> Double)?
    
    init(timeoutGetter: ((PSServiceMap<T,D>) -> Double)?) {
        self.timeoutGetter = timeoutGetter
    }
    
    /// Called to modify a request before sending
    public func prepare(_ request: URLRequest, target: TargetType) -> URLRequest {
        var req = request;
        if let timeout = self.timeoutGetter?(target as! PSServiceMap<T,D>) {
            req.timeoutInterval = timeout;
        }
        return req;
    }
    
    
}


//A Generic class for making network requests (to be subclassed for each section of the API eg. AvatarService, EventService, UserService etc

public class PSService<T:TargetType, V:PSCachedModel, D: TestData> {


	var baseUrl: String = "";
    
	//the actual object used to make the requests
	lazy var provider: MoyaProvider<T> = self.getProvider();
	var authToken: String?

    public var getTimeout: ((PSServiceMap<V,D>) -> Double)?
    
	/// get a MoyaProvider to make API calls
	func getProvider() -> MoyaProvider<T> {
            let provider = MoyaProvider<T>(stubClosure: {
                _ in
                if PSServiceManager.isTesting {
                    return .immediate;
                } else {
                    return .never
                }
            }, plugins: [
					AuthPlugin(tokenClosure: { return PSServiceManager.authToken }),
					TimeoutPlugin<V, D>(timeoutGetter: self.getTimeout),
					NetworkLoggerPlugin()
				]
			)
			return provider;
	}

	// get a

    public init(timeoutIntervalGetter: ((PSServiceMap<V,D>) -> Double)?) {
        self.getTimeout = timeoutIntervalGetter;

	}

	

	//a wrapper for a request which returns a single object, type is the type of request, defined in the API map
	public func makeRequest(_ type: T) -> Promise<V> {
		let promise = Promise<V>.pending();
		Background.runInBackground {
			self.provider.request(type, completion: {
				result in
				switch result {
					case let .success(moyaResponse):
						do {
							let object = try moyaResponse.map(to: V.self);
							Background.runInMainThread {
								promise.fulfill(object);
							}
						}
						catch {
							print(error);
							print(type);
							Background.runInMainThread {
								promise.reject(error);
							}
						}
						break;
					case let .failure(error):
						Background.runInMainThread {
							promise.reject(error);
						}
						break;
				}
			});
		}
		return promise.promise;
	}

	public func makeRequestNoObjectReturn(_ type: T) -> Promise<Void> {
		let promise = Promise<Void>.pending();
		Background.runInBackground {
			self.provider.request(type, completion: {
				result in
				switch result {
					case let .success(moyaResponse):
						do {
							try moyaResponse.filterSuccessfulStatusAndRedirectCodes();
							Background.runInMainThread {
								promise.fulfill();
							}

						}
						catch {
							print(error);
							Background.runInMainThread {
								promise.reject(error);
							}
						}
						break;
					case let .failure(error):
						Background.runInMainThread {
							promise.reject(error);
						}
						break;
				}
			});
		}

		return promise.promise;
	}


	//a wrapper for a request which returns an array of objects
	public func makeRequestArray(_ type: T) -> Promise<[V]> {
		let promise = Promise<[V]>.pending();
		Background.runInBackground {
			self.provider.request(type, completion: {
				result in
				switch result {
					case let .success(moyaResponse):
						do {
							let objects = try moyaResponse.map(to: [V.self]) as! [V];
							Background.runInMainThread {
								promise.fulfill(objects);
							}
						}
						catch {
							print(error);
							Background.runInMainThread {
								promise.reject(error);
							}
						}
						break;
					case let .failure(error):
						Background.runInMainThread {
							promise.reject(error);
						}
						break;
				}
			});
		}

		return promise.promise;
	}


}
