//
//  HTTPServerTests.swift
//  HTTPServerTests
//
//  Tests for UserStore pagination, filtering, and edge-case handling.
//

import Foundation
import Testing

@Suite("UserStore")
struct UserStoreTests {

    @Test("First page returns a full page with correct metadata")
    func firstPage() async {
        let store = UserStore()
        let response = await store.getUsers(page: 1, size: 10, status: nil)
        #expect(response.users.count == 10)
        #expect(response.metadata.currentPage == 1)
        #expect(response.metadata.pageSize == 10)
        #expect(response.metadata.totalPages == 5) // 50 users / 10
        #expect(response.users.first?.id == "u1")
        #expect(response.users.last?.id == "u10")
    }

    @Test("Second page is offset correctly")
    func secondPage() async {
        let store = UserStore()
        let response = await store.getUsers(page: 2, size: 5, status: nil)
        #expect(response.users.count == 5)
        #expect(response.users.first?.id == "u6")
        #expect(response.users.last?.id == "u10")
        #expect(response.metadata.totalPages == 10) // 50 / 5
    }

    @Test("Last page returns the remaining users")
    func lastPage() async {
        let store = UserStore()
        let response = await store.getUsers(page: 5, size: 10, status: nil)
        #expect(response.users.count == 10)
        #expect(response.users.last?.id == "u50")
    }

    @Test("A page size larger than the data set returns everything on one page")
    func oversizedPage() async {
        let store = UserStore()
        let response = await store.getUsers(page: 1, size: 100, status: nil)
        #expect(response.users.count == 50)
        #expect(response.metadata.totalPages == 1)
    }

    @Test("totalPages rounds up for a partial final page")
    func totalPagesRoundsUp() async {
        let store = UserStore()
        let response = await store.getUsers(page: 1, size: 7, status: nil)
        #expect(response.metadata.totalPages == 8) // ceil(50 / 7)
    }

    @Test("Requesting a page beyond the data returns an empty page with accurate metadata")
    func pageBeyondData() async {
        let store = UserStore()
        let response = await store.getUsers(page: 6, size: 10, status: nil)
        #expect(response.users.isEmpty)
        #expect(response.metadata.currentPage == 6)
        #expect(response.metadata.totalPages == 5)
    }

    @Test("Filtering by active status returns only active users")
    func filterActive() async {
        let store = UserStore()
        let response = await store.getUsers(page: 1, size: 100, status: "active")
        #expect(response.users.count == 25)
        #expect(response.users.allSatisfy { $0.status == "active" })
    }

    @Test("Filtering by inactive status returns only inactive users")
    func filterInactive() async {
        let store = UserStore()
        let response = await store.getUsers(page: 1, size: 100, status: "inactive")
        #expect(response.users.count == 25)
        #expect(response.users.allSatisfy { $0.status == "inactive" })
    }

    @Test("Filtered results paginate independently of the full set")
    func filteredPagination() async {
        let store = UserStore()
        let response = await store.getUsers(page: 1, size: 10, status: "active")
        #expect(response.users.count == 10)
        #expect(response.metadata.totalPages == 3) // ceil(25 / 10)
    }

    @Test("A size of zero is handled without dividing by zero")
    func zeroSize() async {
        let store = UserStore()
        let response = await store.getUsers(page: 1, size: 0, status: nil)
        #expect(response.users.isEmpty)
        #expect(response.metadata.totalPages == 1)
        #expect(response.metadata.pageSize == 0)
    }

    @Test("A non-positive page is handled without negative indexing", arguments: [0, -3])
    func nonPositivePage(page: Int) async {
        let store = UserStore()
        let response = await store.getUsers(page: page, size: 10, status: nil)
        #expect(response.users.isEmpty)
    }

    @Test("Paging through the whole data set covers every user exactly once")
    func fullCoverageNoDuplicates() async {
        let store = UserStore()
        var seen: [String] = []
        for page in 1...5 {
            let response = await store.getUsers(page: page, size: 10, status: nil)
            seen.append(contentsOf: response.users.map { $0.id })
        }
        #expect(seen.count == 50)
        #expect(Set(seen).count == 50)
    }

    @Test("Mock users alternate status by index")
    func statusAlternatesByIndex() async {
        let store = UserStore()
        let response = await store.getUsers(page: 1, size: 50, status: nil)
        let u1 = response.users.first { $0.id == "u1" }
        let u2 = response.users.first { $0.id == "u2" }
        #expect(u1?.status == "inactive") // odd index
        #expect(u2?.status == "active")   // even index
    }
}
