//
// ConcurrencyTests.swift
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

@Suite("Concurrency")
struct ConcurrencyTests {

    private func get(_ path: String, query: [String: String] = [:]) -> HTTPRequest {
        HTTPRequest(method: "GET", path: path, queryParameters: query, headers: [:])
    }

    @Test("Concurrent GET /users requests all succeed and decode")
    func concurrentHandleRequestsAreConsistent() async throws {
        let handler = RequestHandler(userStore: UserStore())

        try await withThrowingTaskGroup(of: Int.self) { group in
            for _ in 0..<100 {
                group.addTask {
                    let response = await handler.handleRequest(self.get("/users", query: ["page": "1", "size": "10"]))
                    let body = try #require(response.body)
                    _ = try JSONDecoder().decode(APIResponse.self, from: body)
                    return response.statusCode
                }
            }

            var count = 0
            for try await statusCode in group {
                #expect(statusCode == 200)
                count += 1
            }
            #expect(count == 100)
        }
    }

    @Test("Concurrent store reads return page sizes matching their requests")
    func concurrentUserStoreAccess() async {
        let store = UserStore()

        await withTaskGroup(of: Bool.self) { group in
            for index in 0..<200 {
                let size = (index % 5) + 1
                group.addTask {
                    let response = await store.getUsers(page: 1, size: size, status: nil)
                    // A first page must never exceed the requested size, and with
                    // 50 users a small page is always full.
                    return response.users.count == size && response.metadata.pageSize == size
                }
            }

            for await isConsistent in group {
                #expect(isConsistent)
            }
        }
    }
}
