//
// ResponseSerializationTests.swift
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
