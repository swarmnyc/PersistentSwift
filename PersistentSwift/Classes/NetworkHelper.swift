//
//  NetworkHelper.swift
//  Pods
//
//  Created by Alex Hartwell on 2/5/17.
//
//

import Foundation
import Moya
import SwiftyJSON
import PromiseKit
import PersistentSwift
import Alamofire


extension Response {

	/// Maps data received from the signal into an object which implements the ALSwiftyJSONAble protocol.
	/// If the conversion fails, the signal errors.
	public func map<T:PSCachedModel>(to type: T.Type) throws -> T {
		let jsonObject = try mapJSON()

		guard let mappedObject = T(json: JSON(jsonObject)["data"]) else {
			throw MoyaError.jsonMapping(self)
		}

		return mappedObject
	}

	/// Maps data received from the signal into an array of objects which implement the ALSwiftyJSONAble protocol
	/// If the conversion fails, the signal errors.
	public func map<T:PSCachedModel>(to type: [T.Type]) throws -> [T] {
		let jsonObject = try mapJSON()

		let mappedArray = JSON(jsonObject)["data"];
		let mappedObjectsArray = mappedArray.arrayValue.flatMap {
			T(json: $0)
		}

		return mappedObjectsArray
	}

}


struct AuthPlugin: PluginType {
	let tokenClosure: (() -> String?)

	func prepare(_ request: URLRequest, target: TargetType) -> URLRequest {

		if let token = tokenClosure() {
			var request = request
			request.addValue("Bearer " + token, forHTTPHeaderField: "Authorization")
			return request
		}
		else {
			return request;
		}
	}
}

public enum PSServiceMap<T:PSCachedModel, D:TestData> {
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
		return URL(string: PSServiceManager.constants.baseUrl)!;
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


public protocol TestData {
	static var getTestData: Data { get }
	static var getListTestData: Data { get }
	static var getListWithParamsTestData: Data { get }
	static var getCreateTestData: Data { get }
	static var deleteTestData: Data { get }
	static var getListPaginatedTestData: Data { get }
}

open class NoTestData: TestData {

	public static var getTestData: Data {
		return Data();
	}

	public static var getListWithParamsTestData: Data {
		return Data();
	}

	public static var getListTestData: Data {
		return Data();
	}

	public static var getCreateTestData: Data {
		return Data();
	}

	public static var deleteTestData: Data {
		return Data();
	}

	public static var getListPaginatedTestData: Data {
		return Data();
	}

}


struct ServiceConstants {
	var baseUrl: String
}

