//
// RequestParsingTests.swift
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

@Suite("RequestHandler.parseRequest")
struct RequestParsingTests {

    private func makeHandler() -> RequestHandler {
        RequestHandler(userStore: UserStore())
    }

    @Test("Parses method, path, query, and headers from a well-formed request")
    func parsesFullRequest() throws {
        let handler = makeHandler()
        let raw = "GET /users?page=2&size=5&status=active HTTP/1.1\r\nHost: localhost:8080\r\nAccept: */*\r\n\r\n"
        let request = try #require(handler.parseRequest(data: raw))
        #expect(request.method == "GET")
        #expect(request.path == "/users")
        #expect(request.queryParameters["page"] == "2")
        #expect(request.queryParameters["size"] == "5")
        #expect(request.queryParameters["status"] == "active")
        #expect(request.headers["Host"] == "localhost:8080")
        #expect(request.headers["Accept"] == "*/*")
    }

    @Test("Parses a request with no query parameters")
    func parsesNoQuery() throws {
        let handler = makeHandler()
        let request = try #require(handler.parseRequest(data: "GET / HTTP/1.1\r\n\r\n"))
        #expect(request.path == "/")
        #expect(request.queryParameters.isEmpty)
    }

    @Test("Preserves the method without validating it")
    func preservesMethod() throws {
        let handler = makeHandler()
        let request = try #require(handler.parseRequest(data: "POST /users HTTP/1.1\r\n\r\n"))
        #expect(request.method == "POST")
    }

    @Test("Returns nil for an empty request")
    func emptyRequestIsNil() {
        let handler = makeHandler()
        #expect(handler.parseRequest(data: "") == nil)
    }

    @Test("Returns nil when the request line is missing the HTTP version")
    func missingVersionIsNil() {
        let handler = makeHandler()
        #expect(handler.parseRequest(data: "GET /\r\n\r\n") == nil)
    }

    @Test("Returns nil when the third token is not an HTTP version")
    func nonHTTPVersionIsNil() {
        let handler = makeHandler()
        #expect(handler.parseRequest(data: "GET / SPDY/1\r\n\r\n") == nil)
    }

    @Test("Returns nil for a single garbage token")
    func garbageIsNil() {
        let handler = makeHandler()
        #expect(handler.parseRequest(data: "GARBAGE") == nil)
    }

    @Test("Trims whitespace around header values")
    func trimsHeaderValues() throws {
        let handler = makeHandler()
        let request = try #require(handler.parseRequest(data: "GET / HTTP/1.1\r\nX-Custom:    spaced   \r\n\r\n"))
        #expect(request.headers["X-Custom"] == "spaced")
    }
}
