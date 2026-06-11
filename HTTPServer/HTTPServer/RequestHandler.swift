//
// RequestHandler.swift
// HTTPServer
//
// MIT License
//
// Copyright (c) 2026 SarahUniverse
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.
//

import Foundation

/// Parses raw HTTP requests, routes them to the user API, and serializes the
/// resulting responses.
struct RequestHandler: RequestRouting {
    private let userStore: UserStore

    /// The welcome body for `GET /`, encoded once. The payload is a fixed
    /// dictionary that cannot realistically fail to encode, so a literal fallback
    /// is used instead of `try!` to keep the handler free of forced operations.
    private static let welcomeBody: Data = (try? JSONEncoder().encode(["message": "Welcome to the User API"]))
        ?? Data(#"{"message":"Welcome to the User API"}"#.utf8)

    init(userStore: UserStore) {
        self.userStore = userStore
    }

    /// Parses a raw request string into an ``HTTPRequest``.
    ///
    /// - Returns: A parsed request, or `nil` when the request is empty or the
    ///   request line does not end in an `HTTP/` version token.
    func parseRequest(data: String) -> HTTPRequest? {
        let lines = data.split(separator: "\r\n")
        guard !lines.isEmpty else {
            Logger.log("Empty request received")
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

    /// Routes a parsed request to a response.
    ///
    /// Only `GET` is supported. `GET /users` accepts `page`, `size`, and `status`
    /// query parameters. A non-numeric `page` or `size` falls back to the default
    /// (page 1, size 10) rather than failing, while a non-positive value or an
    /// unrecognized `status` yields `400 Bad Request`.
    func handleRequest(_ request: HTTPRequest) async -> HTTPResponse {
        guard request.method == "GET" else {
            Logger.log("Unsupported method: \(request.method)")
            return HTTPResponse(statusCode: 405, statusText: "Method not allowed", headers: ["Content-Length": "0"], body: nil)
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
                Logger.log("Responding to GET /users?page=\(page)&size=\(size)&status=\(status ?? "all") with 200 OK")
                return HTTPResponse(statusCode: 200, statusText: "OK", headers: headers, body: jsonData)
            } catch {
                Logger.log("JSON encoding error: \(error)")
                return HTTPResponse(statusCode: 500, statusText: "Internal Server Error", headers: ["Content-Length": "0"], body: nil)
            }

        case "/":
            let jsonData = Self.welcomeBody
            let headers = [
                "Content-Type": "application/json",
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

    /// Serializes a response into the bytes written back to the client.
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
