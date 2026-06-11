//
//  ResponseSerializationTests.swift
//  HTTPServerTests
//
//  Tests for RequestHandler.serializeResponse.
//

import Foundation
import Testing

@Suite("RequestHandler.serializeResponse")
struct ResponseSerializationTests {

    private let handler = RequestHandler(userStore: UserStore())

    @Test("Serializes the status line, a header, a blank line, and the body")
    func serializesWithBody() throws {
        let response = HTTPResponse(
            statusCode: 200,
            statusText: "OK",
            headers: ["Content-Type": "application/json"],
            body: Data("hello".utf8)
        )
        let data = handler.serializeResponse(response)
        let text = try #require(String(data: data, encoding: .utf8))
        #expect(text.hasPrefix("HTTP/1.1 200 OK\r\n"))
        #expect(text.contains("Content-Type: application/json\r\n"))
        #expect(text.hasSuffix("\r\n\r\nhello"))
    }

    @Test("Serializes a response with no body and no trailing payload")
    func serializesWithoutBody() throws {
        let response = HTTPResponse(
            statusCode: 404,
            statusText: "Not Found",
            headers: ["Content-Length": "0"],
            body: nil
        )
        let data = handler.serializeResponse(response)
        let text = try #require(String(data: data, encoding: .utf8))
        #expect(text == "HTTP/1.1 404 Not Found\r\nContent-Length: 0\r\n\r\n")
    }

    @Test("Appends raw body bytes after the header terminator")
    func appendsBinaryBody() {
        let payload = Data([0x01, 0x02, 0x03])
        let response = HTTPResponse(statusCode: 200, statusText: "OK", headers: [:], body: payload)
        let data = handler.serializeResponse(response)
        #expect(data.starts(with: Data("HTTP/1.1 200 OK\r\n\r\n".utf8)))
        #expect(Array(data.suffix(3)) == [0x01, 0x02, 0x03])
    }

    @Test("Includes every header in the output")
    func includesAllHeaders() throws {
        let response = HTTPResponse(
            statusCode: 200,
            statusText: "OK",
            headers: ["Content-Type": "application/json", "Connection": "close"],
            body: nil
        )
        let data = handler.serializeResponse(response)
        let text = try #require(String(data: data, encoding: .utf8))
        #expect(text.contains("Content-Type: application/json\r\n"))
        #expect(text.contains("Connection: close\r\n"))
    }
}
