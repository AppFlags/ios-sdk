
import Foundation
import AppFlagsSwiftProtobufs

enum FlagsApiError: Error {
    case InvalidUrl
    case InvalidClientKey
    case UnexpectedError
    case BadResponse(statusCode: Int, message: String)
}

typealias Config = (config: Configuration?, error: Error?)
typealias GetConfigCompletionHandler = (Config) -> Void

class FlagsApi {
    let clientKey: String
    let edgeUrl: String
    let platformData: Appflags_PlatformData
    
    init(clientKey: String, edgeUrl: String) {
        self.clientKey = clientKey
        self.edgeUrl = edgeUrl
        self.platformData = PlatformUtil.getPlatformData()
    }
    
    public func getConfiguration(
        user: AppFlagsUser,
        loadType: Appflags_ConfigurationLoadType,
        getUpdateAt: Int64?,
        completion: @escaping GetConfigCompletionHandler
    ) throws {
        var getFlagsRequest = Appflags_GetFlagRequest()
        getFlagsRequest.configurationID = self.clientKey
        getFlagsRequest.loadType = loadType
        getFlagsRequest.platformData = self.platformData
        getFlagsRequest.user = ProtobufConverters.toUserProto(user: user)
        if let getUpdateAt = getUpdateAt {
            getFlagsRequest.getUpdateAt = getUpdateAt
        }
        
        let encodedGetFlagRequest = try getFlagsRequest.serializedData().base64EncodedString()
        let requestBody = GetFlagRequestBody(request: encodedGetFlagRequest)
        let requestBodyJson = try JSONEncoder().encode(requestBody)
        
        guard let url: URL = URL(string: self.edgeUrl + "/configuration/v1/flags") else {
            completion((nil, FlagsApiError.InvalidUrl))
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = requestBodyJson
        
        let task = URLSession.shared.dataTask(with: request) { (data: Data?, response: URLResponse?, error: Error?) in
            if let error = error {
                Logger.error("Error retreiving feature flags", error)
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                Logger.error("Response was not an HTTPURLResponse")
                return
            }
            let statusCode = httpResponse.statusCode
            if (statusCode == 404) {
                completion((nil, FlagsApiError.InvalidClientKey))
                Logger.error("Retrieving flags failed due to invalid sdk key")
                return
            }
            if (statusCode != 200) {
                var errorMessage = String(data: data!, encoding: .utf8)!
                Logger.error("Error getting flags: " + errorMessage)
                completion((nil, FlagsApiError.BadResponse(statusCode: statusCode, message: errorMessage) ))
                return
            }
            
            do {
                let responseBody: GetFlagResponseBody = try JSONDecoder().decode(GetFlagResponseBody.self, from: data!)
                let responseData = Data(base64Encoded: responseBody.response)
                let getFlagResponse = try Appflags_GetFlagsResponse(serializedData: responseData!)
                
                let configuration = ProtobufConverters.toConfiguration(getFlagsResponse: getFlagResponse)
                completion((configuration, nil))
            } catch {
                Logger.error("Error decoding retrieved feature flags", error)
            }
        }
        task.resume()
    }
    
}

struct GetFlagRequestBody: Codable {
    let request: String
}

struct GetFlagResponseBody: Codable {
    let response: String
}
