//
//  HTTPServer.swift
//  HTTPServer
//
//  Created by Sarah Clark on 10/22/25.
//

import Foundation

actor UserStore {
    private var users: [User]

    init() {
        // Generate 50 mock users for testing.
        users = (1...50).map { index in
            User (
                id: "u\(index)",
                name: ["Orko", "Molly", "Rachel", "Eric", "Kate"].randomElement()! + "\(index)",
                status: index % 2 == 0 ? "active" : "inactive"
            )
        }
    }

    func getUsers(page: Int, size: Int, status: String?) -> APIResponse {
        // Filter users by status if provided.
        let filteredUsers = status == nil ? users : users.filter { $0.status == status }
        let totalPages = max(1, Int(ceil(Double(filteredUsers.count) / Double(size))))
        let startIndex = (page - 1) * size
        let endIndex = min(startIndex + size, filteredUsers.count)

        // Handle invalid page.
        guard startIndex >= 0 && startIndex < filteredUsers.count else {
            return APIResponse(metadata: Metadata(currentPage: page, totalPages: totalPages, pageSize: size), users:[])
        }

        // Return paginated users.
        let pageUsers = Array(filteredUsers[startIndex..<endIndex])
        return APIResponse(
                metadata: Metadata(currentPage: page, totalPages: totalPages, pageSize: size),
                users: pageUsers
        )
    }

}
