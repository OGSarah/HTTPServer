//
//  RequestHandler.swift
//  HTTPServer
//
//  Created by Sarah Clark on 10/23/25.
//

import Foundation

struct RequestHandler {
    private let userStore: UserStore

    init(userStore: UserStore) {
        self.userStore = userStore
    }

    func parseRequest(data: String) -> HTTPRequest? {
        let lines = data.split(separator: "\r\n")
        guard !lines.isEmpty else {
            Logger.log("Empy request received")
            return nil
        }

        // Parse request line
        let requestLine = lines[0].split(separator: " ")
        guard requestLine.count >= 3, requestLine[2].hasPrefix("HTTP/") else {
            Logger.log("Invalid request line: \(lines[0])")
            return nil
        }

        let method = String(requestLine[0])
        let pathWithQuery = String(requestLine[1])

        // Parse path and query parameters
        let components = URLComponents(string: pathWithQuery)
        let path = components?.path ?? "/"
        let queryParameters = components?.queryItems?.reduce(into: [String: String]()) { result, item in
            result[item.name] = item.value
        } ?? [:]

        // Parse headers
        var headers: [String: String] = [:]
        for line in lines.dropFirst() {
            if line.isEmpty { break }
            let parts = line.split(separator: ":", maxSplits: 1)
            if parts.count == 2 {
                headers[String(parts[0].trimmingCharacters(in: .whitespaces))] = String(parts[1].trimmingCharacters(in: .whitespaces))
            }
        }
        return HTTPRequest(method: method, path: path, queryParameters: queryParameters, headers: headers)
    }

    func handleRequest(_ request: HTTPRequest) async -> HTTPResponse {
        guard request.method == "GET" else {
            Logger.log("Unsupported method: \(request.method)")
            return HTTPResponse(statusCode: 405, statusText:  "Method not allowed", headers: ["Content-Length" : "0"], body: nil)
        }

        switch request.path {
        case "/users":
            let page = Int(request.queryParameters["page"] ?? "1") ?? 1
            let size = Int(request.queryParameters["size"] ?? "10") ?? 10
            let status = request.queryParameters["status"]

            guard page > 0, size > 0 else {
                Logger.log("Invalid query parameters: page=\(page), size=\(size)")
                return HTTPResponse(statusCode: 400, statusText: "Bad Request", headers: ["Content-Length": "0"], body: nil)
            }
            if let status = status, status != "active" && status != "inactive" {
                Logger.log("Invalid status: \(status)")
                return HTTPResponse(statusCode: 400, statusText: "Bad Request", headers: ["Content-Length": "0"], body: nil)
            }

            let responseData = await userStore.getUsers(page: page, size: size, status: status)
            do {
                let jsonData = try JSONEncoder().encode(responseData)
                let headers = [
                    "Content-Type": "application/json",
                    "Content-Length": "\(jsonData.count)",
                    "Connection": "close"
                ]
                Logger.log("Responding to GET /users?page=\(page)&size\(size)&status\(status ?? "all") with 200 OK")
                return HTTPResponse(statusCode: 200, statusText: "OK", headers: headers, body: jsonData)
            } catch {
                Logger.log("JSON encoding error: \(error)")
                return HTTPResponse(statusCode: 500, statusText: "Internal Server Error", headers: ["Content-Length": "0"], body: nil)
            }

        case "/":
            let message = ["message": "Welcome to the User API"]
            let jsonData = try! JSONEncoder().encode(message)
            let headers = [
                "Content-Type" : "application/json",
                "Content-Length": "\(jsonData.count)",
                "Connection": "close"
            ]
            Logger.log("Responding to GET / with 200 OK")
            return HTTPResponse(statusCode: 200, statusText: "OK", headers: headers, body: jsonData)

        default:
            Logger.log("Invalid path: \(request.path)")
            return HTTPResponse(statusCode: 404, statusText: "Not Found", headers: ["Content-Length": "0"], body: nil)
        }
    }

    func serializeResponse(_ response: HTTPResponse) -> Data {
        var responseString = "HTTP/1.1 \(response.statusCode) \(response.statusText)\r\n"
        for (key, value) in response.headers {
            responseString += "\(key): \(value)\r\n"
        }
        responseString += "\r\n"

        var data = Data(responseString.utf8)
        if let body = response.body {
            data.append(body)
        }
        return data
    }

}
