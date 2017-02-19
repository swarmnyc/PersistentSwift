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


public struct TimeoutPlugin<T:PSJSONApiModel, D:TestData, S: PSServiceSettings>: PluginType {
    
    var timeoutGetter: ((PSServiceMap<T,D,S>) -> Double)?
    
    init(timeoutGetter: ((PSServiceMap<T,D,S>) -> Double)?) {
        self.timeoutGetter = timeoutGetter
    }
    
    /// Called to modify a request before sending
    public func prepare(_ request: URLRequest, target: TargetType) -> URLRequest {
        var req = request;
        if let timeout = self.timeoutGetter?(target as! PSServiceMap<T,D,S>) {
            req.timeoutInterval = timeout;
        }
        return req;
    }
    
    
}



public protocol PSServiceSettings {
  
    static var baseUrl: String { get }
    static var isTesting: Bool { get }
    
    static func getTimeout<Model: PSJSONApiModel, TestD: TestData, S: PSServiceSettings>(_ target: PSServiceMap<Model, TestD, S>) -> Double
    static func getAuthToken<Model: PSJSONApiModel, TestD: TestData, S: PSServiceSettings>(_ target: PSServiceMap<Model, TestD, S>) -> String?
    
}


struct TestSettings: PSServiceSettings {
    static var baseUrl: String {
        return "";
    }
    
    static var isTesting: Bool {
        return false;
    }
    
    static func getTimeout<Model : PSJSONApiModel, TestD : TestData, S: PSServiceSettings>(_ target: PSServiceMap<Model, TestD, S>) -> Double {
        return 12;
    }
    
    static func getAuthToken<Model : PSJSONApiModel, TestD : TestData, S: PSServiceSettings>(_ target: PSServiceMap<Model, TestD, S>) -> String? {
        return nil;
    }
    
    
}







//A Generic class for making network requests (to be subclassed for each section of the API eg. AvatarService, EventService, UserService etc

public class PSService<T:PSJSONApiModel, D: TestData, S: PSServiceSettings> {
    
	var baseUrl: String = "";
    
	//the actual object used to make the requests
	lazy var provider: MoyaProvider<PSServiceMap<T, D, S>> = self.getProvider();
	var authToken: String?

    
	/// get a MoyaProvider to make API calls
	func getProvider() -> MoyaProvider<PSServiceMap<T, D, S>> {
            let provider = MoyaProvider<PSServiceMap<T, D, S>>(stubClosure: {
                _ in
                if S.isTesting {
                    return .immediate;
                } else {
                    return .never
                }
            }, plugins: [
                    AuthPlugin<T, D, S>(tokenClosure: S.getAuthToken),
					TimeoutPlugin<T, D, S>(timeoutGetter: S.getTimeout),
					NetworkLoggerPlugin()
				]
			)
			return provider;
	}


	

	//a wrapper for a request which returns a single object, type is the type of request, defined in the API map
	public func makeRequest(_ type: PSServiceMap<T, D, S>) -> Promise<T> {
		let promise = Promise<T>.pending();
			self.provider.request(type, completion: {
				result in
				switch result {
					case let .success(moyaResponse):
                        Background.runInBackground {
                            
                            do {
                                let object = try moyaResponse.map(to: T.self);
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
                        }
						break;
					case let .failure(error):
						Background.runInMainThread {
							promise.reject(error);
						}
						break;
				}
			});
		return promise.promise;
	}

	public func makeRequestNoObjectReturn(_ type: PSServiceMap<T, D, S>) -> Promise<Void> {
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
	public func makeRequestArray(_ type: PSServiceMap<T, D, S>) -> Promise<[T]> {
		let promise = Promise<[T]>.pending();
		Background.runInBackground {
			self.provider.request(type, completion: {
				result in
				switch result {
					case let .success(moyaResponse):
                        Background.runInBackground {
                            do {
                                let objects = try moyaResponse.map(to: [T.self]) as! [T];
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

public enum PSServiceMap<T: PSJSONApiModel, D: TestData, S: PSServiceSettings> {
    case getList
    case getListWith(params: [String: Any])
    case getListPaginated(page: Int, limit: Int, params: [String: Any]);
    case createObject(obj: T)
    case updateObject(obj: T)
    case deleteObject(obj: T)
    case getObject(obj: T)
}


extension PSServiceMap: TargetType {
    
    typealias Model = T;
    typealias TestData = D;
    
    
    /// The target's base `URL`.
    public var baseURL: URL {
        return URL(string: S.baseUrl)!;
    }
    
    /// The path to be appended to `baseURL` to form the full `URL`.
    public var path: String {
        switch self {
        case .getList:
            return "/\(T.modelName)";
        case .getListWith(_):
            return "\(T.modelName)";
        case .getListPaginated(_):
            return "\(T.modelName)";
        case .createObject(let obj):
            return "/\(T.modelName)";
        case .updateObject(let obj):
            return "/\(T.modelName)/\(obj.id)";
        case .deleteObject(let obj):
            return "/\(T.modelName)/\(obj.id)";
        case .getObject(let obj):
            return "/\(T.modelName)/\(obj.id)";
        }
    }
    
    /// The HTTP method used in the request.
    public var method: Moya.Method {
        switch self {
        case .getList:
            return .get;
        case .getListWith(_):
            return .get;
        case .getListPaginated(_):
            return .get;
        case .createObject(_):
            return .post;
        case .updateObject(obj: _):
            return .patch;
        case .deleteObject(_):
            return .delete
        case .getObject(_):
            return .get
        }
    }
    
    /// The parameters to be incoded in the request.
    public var parameters: [String: Any]? {
        switch self {
        case .getList:
            return nil;
        case .getListWith(let params):
            return params;
        case .getListPaginated(let page, let limit, let params):
            var p = params;
            p["page"] = page;
            p["per_page"] = limit;
            return p;
        case .createObject(let obj):
            return obj.getCreateParameters(fromModelName: T.modelName);
        case .updateObject(let obj):
            return obj.getCreateParameters(fromModelName: T.modelName);
        case .deleteObject(_):
            return nil;
        case .getObject(let obj):
            return obj.getCreateParameters(fromModelName: T.modelName);
        }
    }
    
    /// The method used for parameter encoding.
    public var parameterEncoding: ParameterEncoding {
        switch self {
        case .getList:
            return URLEncoding.default;
        case .getListWith(_):
            return URLEncoding.default;
        case .getListPaginated(_):
            return URLEncoding.default;
        case .createObject(_):
            return JSONEncoding.default;
        case .updateObject(_):
            return JSONEncoding.default;
        case .deleteObject(_):
            return URLEncoding.default;
        case .getObject(_):
            return JSONEncoding.default;
        }
    }
    
    /// Provides stub data for use in testing.
    public var sampleData: Data {
        switch self {
        case .getList:
            return D.getListTestData;
        case .getListWith(_):
            return D.getListWithParamsTestData;
        case .getListPaginated(_):
            return D.getListPaginatedTestData;
        case .createObject(_):
            return D.getCreateTestData;
        case .updateObject(_):
            return D.getCreateTestData;
        case .deleteObject(_):
            return D.deleteTestData;
        case .getObject(_):
            return D.getTestData;
        }
    }
    
    /// The type of HTTP task to be performed.
    public var task: Task {
        return Task.request
    }
    
    
}

