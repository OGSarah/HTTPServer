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

        // Guard against invalid pagination parameters. A non-positive size would
        // otherwise divide by zero when computing totalPages, and a non-positive
        // page would produce a negative start index.
        guard size > 0, page > 0 else {
            return APIResponse(metadata: Metadata(currentPage: page, totalPages: 1, pageSize: size), users: [])
        }

        let totalPages = max(1, Int(ceil(Double(filteredUsers.count) / Double(size))))
        let startIndex = (page - 1) * size

        // Requested page is beyond the available data: return an empty page with
        // accurate metadata rather than crashing on an out-of-range slice.
        guard startIndex < filteredUsers.count else {
            return APIResponse(metadata: Metadata(currentPage: page, totalPages: totalPages, pageSize: size), users: [])
        }

        // Return paginated users.
        let endIndex = min(startIndex + size, filteredUsers.count)
        let pageUsers = Array(filteredUsers[startIndex..<endIndex])
        return APIResponse(
                metadata: Metadata(currentPage: page, totalPages: totalPages, pageSize: size),
                users: pageUsers
        )
    }

}
