//
// ConnectionReader.swift
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

import Darwin
import Foundation

/// Reads a request from a client socket and decides its response, independent of
/// the server lifecycle.
///
/// Separating this logic from ``HTTPServer`` keeps the byte-level framing and the
/// routing decision directly unit testable without binding a port.
enum ConnectionReader {
    /// Reads a full HTTP request from a socket, accumulating bytes until
    /// ``RequestFraming`` reports a complete message.
    ///
    /// A `SO_RCVTIMEO` read timeout guards against stalled clients.
    ///
    /// - Throws: ``ServerError/requestTooLarge(limit:)``,
    ///   ``ServerError/invalidEncoding``, ``ServerError/readTimedOut``, or
    ///   ``ServerError/clientDisconnected``.
    static func read(from fd: Int32, configuration: ServerConfiguration) throws -> [UInt8] {
        var timeout = timeval(tv_sec: configuration.readTimeout, tv_usec: 0)
        setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))

        var buffer = [UInt8]()
        var chunk = [UInt8](repeating: 0, count: configuration.readChunkSize)

        while true {
            let bytesRead = recv(fd, &chunk, chunk.count, 0)
            if bytesRead == 0 {
                throw ServerError.clientDisconnected
            }
            if bytesRead < 0 {
                if errno == EAGAIN || errno == EWOULDBLOCK {
                    throw ServerError.readTimedOut
                }
                throw ServerError.clientDisconnected
            }

            buffer.append(contentsOf: chunk[0..<bytesRead])

            switch RequestFraming.evaluate(buffer, maxBytes: configuration.maxRequestBytes) {
            case .complete:
                return buffer
            case .tooLarge:
                throw ServerError.requestTooLarge(limit: configuration.maxRequestBytes)
            case .malformed:
                throw ServerError.invalidEncoding
            case .incomplete:
                continue
            }
        }
    }

    /// Decides the response for a fully read request.
    ///
    /// Non-UTF-8 bytes or an unparseable request line yield `400 Bad Request`;
    /// otherwise the request is routed through `router`.
    static func response(forRawRequest rawBytes: [UInt8], router: any RequestRouting) async -> HTTPResponse {
        guard let requestString = String(bytes: rawBytes, encoding: .utf8) else {
            return .status(400, "Bad Request")
        }
        guard let request = router.parseRequest(data: requestString) else {
            return .status(400, "Bad Request")
        }
        return await router.handleRequest(request)
    }
}
