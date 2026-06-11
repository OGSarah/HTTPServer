//
// RequestFraming.swift
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

/// Decides whether an accumulated buffer of bytes contains a complete HTTP/1.1
/// request.
///
/// The framing logic is kept here as a pure, socket free function so it can be
/// unit tested directly and so the read loop never has to decode partial UTF-8.
/// A request is considered complete once the header terminator (`\r\n\r\n`) has
/// arrived and the body has reached the length declared by `Content-Length`.
enum RequestFraming {
    /// The result of inspecting a partially read request buffer.
    enum Status: Equatable {
        /// More bytes are needed before the request is complete.
        case incomplete
        /// A full request is present. `headerEndIndex` is the index of the first
        /// byte after the `\r\n\r\n` terminator, and `contentLength` is the
        /// declared body length.
        case complete(headerEndIndex: Int, contentLength: Int)
        /// The buffer, or a declared `Content-Length`, exceeds the allowed maximum.
        case tooLarge
        /// The headers are present but the framing is unparseable, for example a
        /// non-numeric `Content-Length`.
        case malformed
    }

    private static let carriageReturn: UInt8 = 0x0D // \r
    private static let lineFeed: UInt8 = 0x0A       // \n

    /// Inspects an accumulated request buffer and reports its framing status.
    ///
    /// - Parameters:
    ///   - buffer: The bytes received so far for a single connection.
    ///   - maxBytes: The largest request, headers plus body, that will be accepted.
    /// - Returns: A ``Status`` describing whether the request is complete, needs
    ///   more bytes, is too large, or is malformed.
    static func evaluate(_ buffer: [UInt8], maxBytes: Int) -> Status {
        if buffer.count > maxBytes {
            return .tooLarge
        }

        guard let terminatorRange = rangeOfHeaderTerminator(in: buffer) else {
            return .incomplete
        }

        let headerEndIndex = terminatorRange.upperBound
        let headerBytes = Array(buffer[0..<terminatorRange.lowerBound])

        switch contentLength(inHeaderBytes: headerBytes) {
        case .failure:
            return .malformed
        case .success(let length):
            if length > maxBytes || headerEndIndex + length > maxBytes {
                return .tooLarge
            }
            if buffer.count - headerEndIndex >= length {
                return .complete(headerEndIndex: headerEndIndex, contentLength: length)
            }
            return .incomplete
        }
    }

    /// Finds the `\r\n\r\n` sequence that separates headers from the body.
    private static func rangeOfHeaderTerminator(in buffer: [UInt8]) -> Range<Int>? {
        guard buffer.count >= 4 else { return nil }
        var index = 0
        let lastStart = buffer.count - 4
        while index <= lastStart {
            if buffer[index] == carriageReturn,
               buffer[index + 1] == lineFeed,
               buffer[index + 2] == carriageReturn,
               buffer[index + 3] == lineFeed {
                return index..<(index + 4)
            }
            index += 1
        }
        return nil
    }

    /// Parses the `Content-Length` header from the header bytes.
    ///
    /// - Returns: `.success(0)` when the header is absent, `.success(value)` for a
    ///   valid non-negative integer, or `.failure` for a malformed value.
    private static func contentLength(inHeaderBytes headerBytes: [UInt8]) -> Result<Int, FramingFailure> {
        guard let headerText = String(bytes: headerBytes, encoding: .utf8) else {
            return .failure(.malformed)
        }

        for line in headerText.split(separator: "\r\n") {
            let parts = line.split(separator: ":", maxSplits: 1)
            guard parts.count == 2 else { continue }
            let name = parts[0].trimmingCharacters(in: .whitespaces).lowercased()
            guard name == "content-length" else { continue }

            let rawValue = parts[1].trimmingCharacters(in: .whitespaces)
            guard let length = Int(rawValue), length >= 0 else {
                return .failure(.malformed)
            }
            return .success(length)
        }

        // No Content-Length header means no body.
        return .success(0)
    }

    private enum FramingFailure: Error {
        case malformed
    }
}
