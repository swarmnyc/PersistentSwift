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

public extension Response {

	/// Maps data received from the signal into an object which implements the ALSwiftyJSONAble protocol.
	/// If the conversion fails, the signal errors.
    public func map<T:PSJSONApiModel>(to type: T.Type) throws -> T {
        let objStore: JSONAPIServiceModelStore = JSONAPIServiceModelStore()
		let jsonObject = try mapJSON()
        let json = JSON(jsonObject)
        guard let mappedObject = T(json: json["data"], include: json["included"], objStore: objStore) else {
			throw MoyaError.jsonMapping(self)
		}

		return mappedObject
	}

	/// Maps data received from the signal into an array of objects which implement the ALSwiftyJSONAble protocol
	/// If the conversion fails, the signal errors.
    public func map<T:PSJSONApiModel>(to type: [T.Type]) throws -> [T] {
        let objStore: JSONAPIServiceModelStore = JSONAPIServiceModelStore()
		let jsonObject = try mapJSON()
        let json = JSON(jsonObject)
		let mappedArray = json["data"];
		let mappedObjectsArray = mappedArray.arrayValue.flatMap {
            T(json: $0, include: json["included"], objStore: objStore)
		}

		return mappedObjectsArray
	}

}


open class AuthPlugin<T:PSJSONApiModel>: PluginType {
	public var tokenClosure: ((JSONAPIRequest<T>) -> String?)

    public init(tokenClosure: @escaping ((JSONAPIRequest<T>) -> String?)) {
        self.tokenClosure = tokenClosure
    }
    
    
	public func prepare(_ request: URLRequest, target: TargetType) -> URLRequest {

		if let token = tokenClosure(target as! JSONAPIRequest<T>) {
			var request = request
			request.addValue("Bearer " + token, forHTTPHeaderField: "Authorization")
			return request
		}
		else {
			return request;
		}
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



