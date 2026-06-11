//
// RequestFramingTests.swift
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

@Suite("RequestFraming.evaluate")
struct RequestFramingTests {

    private let maxBytes = 64 * 1024

    private func bytes(_ string: String) -> [UInt8] {
        Array(string.utf8)
    }

    @Test("Reports incomplete when the header terminator has not arrived")
    func incompleteWhenNoTerminator() {
        let buffer = bytes("GET / HTTP/1.1\r\nHost: localhost\r\n")
        #expect(RequestFraming.evaluate(buffer, maxBytes: maxBytes) == .incomplete)
    }

    @Test("Reports complete for a request with no body")
    func completeWithNoBody() {
        let buffer = bytes("GET / HTTP/1.1\r\nHost: localhost\r\n\r\n")
        #expect(RequestFraming.evaluate(buffer, maxBytes: maxBytes) == .complete(headerEndIndex: buffer.count, contentLength: 0))
    }

    @Test("Reports complete when the declared body has fully arrived")
    func completeWithExactBody() {
        let buffer = bytes("POST /users HTTP/1.1\r\nContent-Length: 5\r\n\r\nhello")
        switch RequestFraming.evaluate(buffer, maxBytes: maxBytes) {
        case .complete(_, let contentLength):
            #expect(contentLength == 5)
        default:
            Issue.record("Expected a complete request")
        }
    }

    @Test("Reports incomplete when the body is shorter than Content-Length")
    func incompleteWhenBodyShort() {
        let buffer = bytes("POST /users HTTP/1.1\r\nContent-Length: 5\r\n\r\nhi")
        #expect(RequestFraming.evaluate(buffer, maxBytes: maxBytes) == .incomplete)
    }

    @Test("Becomes complete once a body split across reads is concatenated")
    func splitAcrossChunks() {
        let head = bytes("POST /users HTTP/1.1\r\nContent-Length: 5\r\n\r\nhel")
        #expect(RequestFraming.evaluate(head, maxBytes: maxBytes) == .incomplete)
        let full = head + bytes("lo")
        switch RequestFraming.evaluate(full, maxBytes: maxBytes) {
        case .complete(_, let contentLength):
            #expect(contentLength == 5)
        default:
            Issue.record("Expected a complete request after concatenation")
        }
    }

    @Test("Reports too large when the buffer exceeds the maximum")
    func tooLargeByAccumulation() {
        let buffer = bytes("GET / HTTP/1.1\r\nHost: localhost\r\n\r\n")
        #expect(RequestFraming.evaluate(buffer, maxBytes: 8) == .tooLarge)
    }

    @Test("Reports too large when the declared Content-Length exceeds the maximum")
    func tooLargeByDeclaredContentLength() {
        let buffer = bytes("POST /users HTTP/1.1\r\nContent-Length: 1000\r\n\r\n")
        #expect(RequestFraming.evaluate(buffer, maxBytes: 100) == .tooLarge)
    }

    @Test("Reports malformed for a non-numeric Content-Length")
    func malformedContentLength() {
        let buffer = bytes("POST /users HTTP/1.1\r\nContent-Length: abc\r\n\r\n")
        #expect(RequestFraming.evaluate(buffer, maxBytes: maxBytes) == .malformed)
    }

    @Test("Recognizes Content-Length regardless of header name casing")
    func caseInsensitiveContentLength() {
        let buffer = bytes("POST /users HTTP/1.1\r\ncontent-length: 3\r\n\r\nabc")
        switch RequestFraming.evaluate(buffer, maxBytes: maxBytes) {
        case .complete(_, let contentLength):
            #expect(contentLength == 3)
        default:
            Issue.record("Expected a complete request")
        }
    }
}
