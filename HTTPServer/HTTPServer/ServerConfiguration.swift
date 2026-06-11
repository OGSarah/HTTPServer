//
// ServerConfiguration.swift
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

/// Tunable settings for an ``HTTPServer`` instance.
///
/// Inject a configuration to control the listening port, connection limits, and
/// read behavior. ``default`` provides sensible values, and ``fromEnvironment()``
/// layers `PORT` and `HOST` overrides on top so the server can be reconfigured
/// without recompiling.
struct ServerConfiguration: Sendable {
    /// The host the server reports itself as serving. The socket currently binds
    /// to all interfaces (`INADDR_ANY`); this value is informational.
    var host: String

    /// The TCP port to listen on.
    var port: Int

    /// The backlog passed to `listen()`, bounding the queue of pending connections.
    var backlog: Int32

    /// The maximum number of bytes accepted for a single request before the
    /// connection is rejected with `413 Payload Too Large`.
    var maxRequestBytes: Int

    /// The per-connection read timeout, in seconds, applied via `SO_RCVTIMEO`.
    var readTimeout: Int

    /// The size of each `recv()` buffer while reading a request.
    var readChunkSize: Int

    /// The default configuration: port 8080, a 64 KB request cap, and a 15 second
    /// read timeout.
    static let `default` = ServerConfiguration(
        host: "0.0.0.0",
        port: 8080,
        backlog: 10,
        maxRequestBytes: 64 * 1024,
        readTimeout: 15,
        readChunkSize: 4096
    )

    /// Builds a configuration from the process environment, falling back to
    /// ``default`` for any value that is missing or invalid.
    ///
    /// Recognized variables:
    /// - `PORT`: overrides the listening port when it parses as a positive integer.
    /// - `HOST`: overrides the reported host.
    static func fromEnvironment(_ environment: [String: String] = ProcessInfo.processInfo.environment) -> ServerConfiguration {
        var configuration = ServerConfiguration.default
        if let rawPort = environment["PORT"], let port = Int(rawPort), port > 0 {
            configuration.port = port
        }
        if let host = environment["HOST"], !host.isEmpty {
            configuration.host = host
        }
        return configuration
    }
}
