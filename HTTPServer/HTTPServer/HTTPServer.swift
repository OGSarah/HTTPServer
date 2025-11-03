//
//  HTTPServer.swift
//  HTTPServer
//
//  Created by Sarah Clark on 10/22/25.
//

import Darwin
import Foundation

public final class HTTPServer {
    private let port: Int
    private let userStore: UserStore
    private let requestHandler: RequestHandler

    init(port: Int) {
        self.port = port
        self.userStore = UserStore()
        self.requestHandler = RequestHandler(userStore: userStore)
    }

    func start() {
        // Create socket
        let serverSocket = socket(AF_INET, SOCK_STREAM, 0)
        guard serverSocket >= 0 else {
            Logger.log("Failed to create socket: \(errno)")
            exit(1)
        }

        // Set SO_REUSEADDR
        var reuse = 1
        setsockopt(serverSocket, SOL_SOCKET, SO_REUSEADDR, &reuse, socklen_t(MemoryLayout<Int>.size))

        // Bind socket
        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = in_port_t(port).bigEndian
        addr.sin_addr.s_addr = INADDR_ANY

        let bindResult = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(serverSocket, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard bindResult == 0 else {
            Logger.log("Bind failed: \(errno)")
            close(serverSocket)
            exit(1)
        }

        // Listen
        guard listen(serverSocket, 10) == 0 else {
            Logger.log("Listen failed: \(errno)")
            close(serverSocket)
            exit(1)
        }

        Logger.log("Server started on port \(port)")

        // Accept loop
        let queue = DispatchQueue(label: "com.example.server.client", attributes: .concurrent)
        while true {
            var clientAddr = sockaddr()
            var clientAddrLen = socklen_t(MemoryLayout<sockaddr>.size)
            let clientSocket = accept(serverSocket, &clientAddr, &clientAddrLen)
            guard clientSocket >= 0 else {
                Logger.log("Accept failed: \(errno)")
                continue
            }

            queue.async {
                Task {
                    await self.handleClient(clientSocket)
                }
            }
        }
    }

    private func handleClient(_ clientSocket: Int32) async {
        defer { close(clientSocket) }

        var buffer = [UInt8](repeating: 0, count: 4096)
        let bytesRead = recv(clientSocket, &buffer, buffer.count, 0)
        guard bytesRead > 0 else {
            Logger.log("Failed to read from client or client disconnected: \(errno)")
            return
        }

        guard let requestString = String(bytes: buffer[0..<bytesRead], encoding: .utf8) else {
            Logger.log("Invalid request encoding")
            return
        }

        guard let request = requestHandler.parseRequest(data: requestString) else {
            let response = HTTPResponse(statusCode: 400, statusText: "Bad Request", headers: ["Content-Length": "0"], body: nil)
            sendResponse(clientSocket, response: response)
            return
        }

        let response = await requestHandler.handleRequest(request)
        sendResponse(clientSocket, response: response)
    }

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

// Start the server
// let server = HTTPServer(port: 8080)
// server.start()
