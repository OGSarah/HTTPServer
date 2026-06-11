//
// RequestRouting.swift
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

/// The request handling surface that ``HTTPServer`` depends on.
///
/// Depending on this protocol rather than a concrete type lets the server be
/// driven by a stub router in tests, and keeps parsing, routing, and
/// serialization behind a single, swappable seam.
protocol RequestRouting: Sendable {
    /// Parses a raw request string into a structured ``HTTPRequest``, or returns
    /// `nil` when the request line is missing or invalid.
    func parseRequest(data: String) -> HTTPRequest?

    /// Routes a parsed request to a response.
    func handleRequest(_ request: HTTPRequest) async -> HTTPResponse

    /// Serializes a response into the bytes written back to the client.
    func serializeResponse(_ response: HTTPResponse) -> Data
}
