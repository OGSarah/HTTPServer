//
// RequestReadLoopTests.swift
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

import Darwin
import Foundation
import Testing

@Suite("ConnectionReader read loop")
struct RequestReadLoopTests {

    /// Creates a connected pair of stream sockets. `client` is written to by the
    /// test, `server` is read by ``ConnectionReader/read(from:configuration:)``.
    private func makeSocketPair() -> (client: Int32, server: Int32) {
        var fds: [Int32] = [0, 0]
        let result = socketpair(AF_UNIX, SOCK_STREAM, 0, &fds)
        #expect(result == 0)
        return (fds[0], fds[1])
    }

    private func send(_ string: String, to fd: Int32) {
        let bytes = Array(string.utf8)
        _ = bytes.withUnsafeBytes { Darwin.send(fd, $0.baseAddress, bytes.count, 0) }
    }

    @Test("Reassembles a request delivered in two separate sends")
    func readsRequestSplitAcrossMultipleSends() throws {
        let (client, server) = makeSocketPair()
        defer { close(client); close(server) }

        // Both writes land in the socket buffer before the read loop runs, so the
        // loop must accumulate them across multiple recv calls.
        send("GET /users HTTP/1.1\r\n", to: client)
        send("Host: localhost\r\n\r\n", to: client)

        let bytes = try ConnectionReader.read(from: server, configuration: .default)
        let text = try #require(String(bytes: bytes, encoding: .utf8))
        #expect(text == "GET /users HTTP/1.1\r\nHost: localhost\r\n\r\n")
    }

    @Test("Reads a request whose headers exceed a single recv chunk")
    func readsRequestLargerThanOneChunk() throws {
        let (client, server) = makeSocketPair()
        defer { close(client); close(server) }

        let longValue = String(repeating: "x", count: 5000)
        let request = "GET / HTTP/1.1\r\nX-Long: \(longValue)\r\n\r\n"
        send(request, to: client)

        var smallChunks = ServerConfiguration.default
        smallChunks.readChunkSize = 256
        let bytes = try ConnectionReader.read(from: server, configuration: smallChunks)
        #expect(bytes.count == Array(request.utf8).count)
    }

    @Test("Rejects a request larger than the configured maximum")
    func rejectsRequestOverCap() throws {
        let (client, server) = makeSocketPair()
        defer { close(client); close(server) }

        let request = "GET / HTTP/1.1\r\nX-Long: \(String(repeating: "y", count: 1000))\r\n\r\n"
        send(request, to: client)

        var tinyCap = ServerConfiguration.default
        tinyCap.maxRequestBytes = 64
        tinyCap.readChunkSize = 32

        #expect(throws: ServerError.self) {
            _ = try ConnectionReader.read(from: server, configuration: tinyCap)
        }
    }

    @Test("Times out when the client never finishes the request")
    func timesOutWhenClientStalls() throws {
        let (client, server) = makeSocketPair()
        defer { close(client); close(server) }

        // Send a partial request with no header terminator and never finish. The
        // client end stays open, so recv blocks until SO_RCVTIMEO fires.
        send("GET / HTTP/1.1\r\n", to: client)

        var shortTimeout = ServerConfiguration.default
        shortTimeout.readTimeout = 1

        var thrown: Error?
        do {
            _ = try ConnectionReader.read(from: server, configuration: shortTimeout)
        } catch {
            thrown = error
        }
        #expect(thrown is ServerError)
        if case .readTimedOut = thrown as? ServerError {
            // Expected.
        } else {
            Issue.record("Expected readTimedOut, got \(String(describing: thrown))")
        }
    }

    @Test("Reports disconnect when the client closes before completing the request")
    func reportsDisconnectOnEarlyClose() throws {
        let (client, server) = makeSocketPair()
        defer { close(server) }

        send("GET / HTTP/1.1\r\n", to: client)
        close(client) // Half-open: recv will return 0 once the buffer drains.

        var thrown: Error?
        do {
            _ = try ConnectionReader.read(from: server, configuration: .default)
        } catch {
            thrown = error
        }
        if case .clientDisconnected = thrown as? ServerError {
            // Expected.
        } else {
            Issue.record("Expected clientDisconnected, got \(String(describing: thrown))")
        }
    }

    @Test("Non-UTF-8 request bytes produce a 400 response")
    func invalidUTF8YieldsBadRequest() async {
        let router = RequestHandler(userStore: UserStore())
        let invalidBytes: [UInt8] = [0xFF, 0xFE, 0xFD]
        let response = await ConnectionReader.response(forRawRequest: invalidBytes, router: router)
        #expect(response.statusCode == 400)
    }

    @Test("A well-formed root request produces a 200 response")
    func validRequestYieldsOK() async throws {
        let router = RequestHandler(userStore: UserStore())
        let bytes = Array("GET / HTTP/1.1\r\nHost: localhost\r\n\r\n".utf8)
        let response = await ConnectionReader.response(forRawRequest: bytes, router: router)
        #expect(response.statusCode == 200)
    }
}
