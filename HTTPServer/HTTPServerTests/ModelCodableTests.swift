//
//  ModelCodableTests.swift
//  HTTPServerTests
//
//  Codable round-trip tests for the API models.
//

import Foundation
import Testing

@Suite("Model Codable")
struct ModelCodableTests {

    @Test("User round-trips through JSON")
    func userRoundTrip() throws {
        let user = User(id: "u7", name: "Rachel7", status: "inactive")
        let data = try JSONEncoder().encode(user)
        let decoded = try JSONDecoder().decode(User.self, from: data)
        #expect(decoded.id == user.id)
        #expect(decoded.name == user.name)
        #expect(decoded.status == user.status)
    }

    @Test("User decodes from known JSON")
    func userDecodesFromJSON() throws {
        let json = Data(#"{"id":"u1","name":"Orko1","status":"active"}"#.utf8)
        let user = try JSONDecoder().decode(User.self, from: json)
        #expect(user.id == "u1")
        #expect(user.name == "Orko1")
        #expect(user.status == "active")
    }

    @Test("Metadata round-trips through JSON")
    func metadataRoundTrip() throws {
        let metadata = Metadata(currentPage: 2, totalPages: 5, pageSize: 10)
        let data = try JSONEncoder().encode(metadata)
        let decoded = try JSONDecoder().decode(Metadata.self, from: data)
        #expect(decoded.currentPage == 2)
        #expect(decoded.totalPages == 5)
        #expect(decoded.pageSize == 10)
    }

    @Test("APIResponse round-trips through JSON")
    func apiResponseRoundTrip() throws {
        let response = APIResponse(
            metadata: Metadata(currentPage: 1, totalPages: 3, pageSize: 2),
            users: [
                User(id: "u1", name: "Orko1", status: "inactive"),
                User(id: "u2", name: "Molly2", status: "active")
            ]
        )
        let data = try JSONEncoder().encode(response)
        let decoded = try JSONDecoder().decode(APIResponse.self, from: data)
        #expect(decoded.metadata.totalPages == 3)
        #expect(decoded.users.count == 2)
        #expect(decoded.users.first?.id == "u1")
        #expect(decoded.users.last?.status == "active")
    }

    @Test("APIResponse decodes from known JSON")
    func apiResponseDecodesFromJSON() throws {
        let json = Data("""
        {
          "metadata": { "currentPage": 1, "totalPages": 5, "pageSize": 10 },
          "users": [ { "id": "u1", "name": "Orko1", "status": "inactive" } ]
        }
        """.utf8)
        let decoded = try JSONDecoder().decode(APIResponse.self, from: json)
        #expect(decoded.metadata.pageSize == 10)
        #expect(decoded.users.count == 1)
        #expect(decoded.users.first?.name == "Orko1")
    }
}
