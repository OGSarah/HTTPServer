//
//  RequestParsingTests.swift
//  HTTPServerTests
//
//  Tests for RequestHandler.parseRequest.
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
