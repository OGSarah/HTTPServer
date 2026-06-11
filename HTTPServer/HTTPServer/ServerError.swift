//
// ServerError.swift
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

/// Errors thrown by the server.
///
/// The cases fall into two groups:
/// - Fatal startup failures (`socketCreationFailed`, `setSocketOptionFailed`,
///   `bindFailed`, `listenFailed`) propagate out of ``HTTPServer/start()`` so the
///   entry point can report them and exit.
/// - Per-connection conditions (`requestTooLarge`, `readTimedOut`,
///   `clientDisconnected`, `invalidEncoding`) are caught while handling a single
///   client and translated into an HTTP response or a quiet connection close.
enum ServerError: Error, CustomStringConvertible {
    /// `socket()` failed to create the listening socket.
    case socketCreationFailed(errno: Int32)
    /// `setsockopt()` failed while configuring the listening socket.
    case setSocketOptionFailed(errno: Int32)
    /// `bind()` failed for the given port.
    case bindFailed(port: Int, errno: Int32)
    /// `listen()` failed on the listening socket.
    case listenFailed(errno: Int32)
    /// The client sent more bytes than `maxRequestBytes` allows.
    case requestTooLarge(limit: Int)
    /// The client did not finish sending a request before the read timeout.
    case readTimedOut
    /// The client closed the connection before a full request arrived.
    case clientDisconnected
    /// The request bytes were not valid UTF-8 or could not be framed.
    case invalidEncoding

    var description: String {
        switch self {
        case .socketCreationFailed(let code):
            return "Failed to create socket: \(Self.message(for: code))"
        case .setSocketOptionFailed(let code):
            return "Failed to set socket option: \(Self.message(for: code))"
        case .bindFailed(let port, let code):
            return "Failed to bind port \(port): \(Self.message(for: code))"
        case .listenFailed(let code):
            return "Failed to listen: \(Self.message(for: code))"
        case .requestTooLarge(let limit):
            return "Request exceeded the \(limit) byte limit"
        case .readTimedOut:
            return "Timed out while reading the request"
        case .clientDisconnected:
            return "Client disconnected before sending a complete request"
        case .invalidEncoding:
            return "Request could not be decoded as a valid HTTP message"
        }
    }

    /// Renders a POSIX error code into a human readable string.
    private static func message(for code: Int32) -> String {
        "\(code) (\(String(cString: strerror(code))))"
    }
}
