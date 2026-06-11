//
// RequestRoutingTests.swift
// HTTPServerTests
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
import Testing

@Suite("RequestHandler.handleRequest")
struct RequestRoutingTests {

    private func makeHandler() -> RequestHandler {
        RequestHandler(userStore: UserStore())
    }

    private func get(_ path: String, query: [String: String] = [:]) -> HTTPRequest {
        HTTPRequest(method: "GET", path: path, queryParameters: query, headers: [:])
    }

    @Test("GET /users returns 200 with a decodable JSON body")
    func usersOK() async throws {
        let handler = makeHandler()
        let response = await handler.handleRequest(get("/users"))
        #expect(response.statusCode == 200)
        #expect(response.statusText == "OK")
        #expect(response.headers["Content-Type"] == "application/json")
        let body = try #require(response.body)
        let decoded = try JSONDecoder().decode(APIResponse.self, from: body)
        #expect(decoded.users.count == 10)
    }

    @Test("GET /users honors page and size")
    func usersPaged() async throws {
        let handler = makeHandler()
        let response = await handler.handleRequest(get("/users", query: ["page": "2", "size": "5"]))
        #expect(response.statusCode == 200)
        let body = try #require(response.body)
        let decoded = try JSONDecoder().decode(APIResponse.self, from: body)
        #expect(decoded.users.count == 5)
        #expect(decoded.metadata.currentPage == 2)
    }

    @Test("GET /users filters by status")
    func usersFiltered() async throws {
        let handler = makeHandler()
        let response = await handler.handleRequest(get("/users", query: ["status": "active", "size": "100"]))
        let body = try #require(response.body)
        let decoded = try JSONDecoder().decode(APIResponse.self, from: body)
        #expect(decoded.users.allSatisfy { $0.status == "active" })
        #expect(decoded.users.count == 25)
    }

    @Test("Content-Length header matches the body size")
    func contentLengthMatchesBody() async throws {
        let handler = makeHandler()
        let response = await handler.handleRequest(get("/users"))
        let body = try #require(response.body)
        #expect(response.headers["Content-Length"] == String(body.count))
    }

    @Test("Non-numeric page falls back to the first page")
    func nonNumericPageDefaults() async throws {
        let handler = makeHandler()
        let response = await handler.handleRequest(get("/users", query: ["page": "abc"]))
        #expect(response.statusCode == 200)
        let body = try #require(response.body)
        let decoded = try JSONDecoder().decode(APIResponse.self, from: body)
        #expect(decoded.metadata.currentPage == 1)
    }

    @Test("Invalid status yields 400", arguments: ["bogus", "ACTIVE", ""])
    func invalidStatus(status: String) async {
        let handler = makeHandler()
        let response = await handler.handleRequest(get("/users", query: ["status": status]))
        #expect(response.statusCode == 400)
    }

    @Test("Non-positive page or size yields 400")
    func invalidPaging() async {
        let handler = makeHandler()
        let zeroPage = await handler.handleRequest(get("/users", query: ["page": "0"]))
        #expect(zeroPage.statusCode == 400)
        let zeroSize = await handler.handleRequest(get("/users", query: ["size": "0"]))
        #expect(zeroSize.statusCode == 400)
    }

    @Test("Unsupported methods yield 405", arguments: ["POST", "PUT", "DELETE", "get"])
    func unsupportedMethod(method: String) async {
        let handler = makeHandler()
        let request = HTTPRequest(method: method, path: "/users", queryParameters: [:], headers: [:])
        let response = await handler.handleRequest(request)
        #expect(response.statusCode == 405)
        #expect(response.statusText == "Method not allowed")
    }

    @Test("GET / returns the welcome message")
    func rootWelcome() async throws {
        let handler = makeHandler()
        let response = await handler.handleRequest(get("/"))
        #expect(response.statusCode == 200)
        let body = try #require(response.body)
        let decoded = try JSONDecoder().decode([String: String].self, from: body)
        #expect(decoded["message"] == "Welcome to the User API")
    }

    @Test("Unknown paths yield 404")
    func unknownPath() async {
        let handler = makeHandler()
        let response = await handler.handleRequest(get("/nope"))
        #expect(response.statusCode == 404)
        #expect(response.statusText == "Not Found")
    }
}
