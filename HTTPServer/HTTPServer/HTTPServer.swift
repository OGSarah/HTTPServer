//
// HTTPServer.swift
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
import Dispatch
import Foundation
import Synchronization

/// A from-scratch HTTP/1.1 server built on Darwin BSD sockets.
///
/// The server runs a single blocking acceptor loop on the calling thread. The
/// `accept()` syscall blocks, so it deliberately stays out of structured
/// concurrency; each accepted connection is then dispatched to its own detached
/// `Task` that reads, routes, and responds asynchronously. Reading a connection
/// frames the bytes with ``RequestFraming`` so that large or fragmented requests
/// are handled correctly, and a `SIGINT` handler closes the listening socket for
/// a clean shutdown.
final class HTTPServer: Sendable {
    private let configuration: ServerConfiguration
    private let requestHandler: any RequestRouting

    /// Mutable server state guarded by a mutex so the type remains `Sendable`
    /// without resorting to `@unchecked`.
    private let state = Mutex(State())

    private struct State {
        var isShuttingDown = false
        var listeningSocket: Int32?
    }

    /// Creates a server.
    ///
    /// - Parameters:
    ///   - configuration: Listening and connection settings. Defaults to
    ///     ``ServerConfiguration/default``.
    ///   - router: The request router. Defaults to a ``RequestHandler`` backed by
    ///     a fresh ``UserStore``. Inject a stub to drive the server in tests.
    init(configuration: ServerConfiguration = .default, router: (any RequestRouting)? = nil) {
        self.configuration = configuration
        self.requestHandler = router ?? RequestHandler(userStore: UserStore())
    }

    /// Opens the listening socket and runs the accept loop until shutdown.
    ///
    /// This call blocks the current thread for the lifetime of the server.
    ///
    /// - Throws: ``ServerError`` if the socket cannot be created, configured,
    ///   bound, or set to listen.
    func start() throws {
        let serverSocket = socket(AF_INET, SOCK_STREAM, 0)
        guard serverSocket >= 0 else {
            throw ServerError.socketCreationFailed(errno: errno)
        }

        // Allow the port to be reused immediately after a restart.
        var reuse: Int32 = 1
        guard setsockopt(serverSocket, SOL_SOCKET, SO_REUSEADDR, &reuse, socklen_t(MemoryLayout<Int32>.size)) == 0 else {
            close(serverSocket)
            throw ServerError.setSocketOptionFailed(errno: errno)
        }

        // Bind to the configured port on all interfaces.
        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = in_port_t(configuration.port).bigEndian
        addr.sin_addr.s_addr = INADDR_ANY

        let bindResult = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(serverSocket, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard bindResult == 0 else {
            close(serverSocket)
            throw ServerError.bindFailed(port: configuration.port, errno: errno)
        }

        guard listen(serverSocket, configuration.backlog) == 0 else {
            close(serverSocket)
            throw ServerError.listenFailed(errno: errno)
        }

        state.withLock { $0.listeningSocket = serverSocket }
        let signalSource = installShutdownHandler()
        defer { signalSource.cancel() }

        Logger.log("Server started on port \(configuration.port)")

        // Accept loop: one blocking acceptor thread dispatching async handlers.
        while !state.withLock({ $0.isShuttingDown }) {
            var clientAddr = sockaddr()
            var clientAddrLen = socklen_t(MemoryLayout<sockaddr>.size)
            let clientSocket = accept(serverSocket, &clientAddr, &clientAddrLen)
            guard clientSocket >= 0 else {
                // A closed listening socket unblocks accept during shutdown.
                if state.withLock({ $0.isShuttingDown }) { break }
                Logger.log("Accept failed: \(errno)")
                continue
            }

            Task.detached { [self] in
                await handleClient(clientSocket)
            }
        }

        Logger.log("Server shutting down")
    }

    /// Installs a `SIGINT` handler that flags shutdown and closes the listening
    /// socket, unblocking the accept loop.
    private func installShutdownHandler() -> DispatchSourceSignal {
        // Ignore the default terminating handler so the dispatch source can run.
        signal(SIGINT, SIG_IGN)
        let source = DispatchSource.makeSignalSource(signal: SIGINT, queue: .global())
        source.setEventHandler { [self] in
            Logger.log("Received interrupt, shutting down")
            let socketToClose: Int32? = state.withLock { state in
                state.isShuttingDown = true
                return state.listeningSocket
            }
            if let socketToClose {
                close(socketToClose)
            }
        }
        source.resume()
        return source
    }

    /// Reads, routes, and responds to a single client connection, then closes it.
    private func handleClient(_ clientSocket: Int32) async {
        defer { close(clientSocket) }

        let rawBytes: [UInt8]
        do {
            rawBytes = try ConnectionReader.read(from: clientSocket, configuration: configuration)
        } catch ServerError.requestTooLarge {
            sendResponse(clientSocket, response: .status(413, "Payload Too Large"))
            return
        } catch ServerError.readTimedOut {
            sendResponse(clientSocket, response: .status(408, "Request Timeout"))
            return
        } catch ServerError.invalidEncoding {
            sendResponse(clientSocket, response: .status(400, "Bad Request"))
            return
        } catch {
            // Client disconnected before sending a complete request.
            Logger.log("Read failed: \(error)")
            return
        }

        let response = await ConnectionReader.response(forRawRequest: rawBytes, router: requestHandler)
        sendResponse(clientSocket, response: response)
    }

    /// Serializes a response and writes it to the client socket.
    private func sendResponse(_ clientSocket: Int32, response: HTTPResponse) {
        let responseData = requestHandler.serializeResponse(response)
        let sent = responseData.withUnsafeBytes { ptr in
            send(clientSocket, ptr.baseAddress, responseData.count, 0)
        }
        if sent < 0 {
            Logger.log("Failed to send response: \(errno)")
        }
    }

}
