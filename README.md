# HTTPServer
A lightweight HTTP server in Swift.

**Goal**: Build a lightweight HTTP server in Swift that handles HTTP GET requests for a paginated user list API, returning JSON responses with user data and metadata. The server will use low-level socket programming with Darwin APIs, handle multiple clients concurrently, parse HTTP requests, and generate JSON responses, all without external frameworks. The project will deepen your understanding of networking, HTTP, and Swift's capabilities, while aligning with the paginated user list problem.

**Scope**:

-   **Endpoint**: GET /users?page={pageNumber}&size={pageSize}&status={status} (e.g., /users?page=1&size=10&status=active).
-   **Response**: JSON with metadata (currentPage, totalPages, pageSize) and users (array of {id, name, status}).
- **Features**:
      -  Handle multiple client connections concurrently.
    -   Parse HTTP GET requests and query parameters.
    -   Support pagination and status filtering.
    -   Handle errors (e.g., invalid requests, server issues).
    -   Log requests and responses for debugging.

-   **Time Estimate**: 2--3 days (15--20 hours) over a long weekend, depending on your familiarity with Swift and networking.

**Key Concepts**

1.  **HTTP Protocol**:

-   **Request**: Consists of a request line (e.g., GET /users?page=1&size=10 HTTP/1.1), headers (e.g., Host, Accept), and an optional body (not needed for GET).
-   **Response**: Includes a status line (e.g., HTTP/1.1 200 OK), headers (e.g., Content-Type: application/json), and a body (JSON data).
-   **HTTP/1.1**: Support basic features like persistent connections (keep-alive) for learning purposes.

3.  **Socket Programming**:

-   Use Darwin's socket APIs (socket, bind, listen, accept, recv, send) to create a TCP server.
-   Sockets enable communication over TCP/IP, with the server listening on a port (e.g., 8080) for incoming client connections.

5.  **Concurrency**:

-   Handle multiple clients using Grand Central Dispatch (GCD) DispatchQueue to process each connection on a separate thread or queue.
-   Ensure thread safety when accessing shared resources (e.g., user data store).

7.  **JSON Handling**:

-   Use Foundation's JSONEncoder and JSONDecoder for serializing responses and parsing potential request bodies.
-   Define Codable structs for the API response format from your paginated user list problem.

9.  **Data Model**:

Match the JSON structure from your previous problem:
```
struct User: Codable {
    let id: String
    let name: String
    let status: String // "active" or "inactive"
}
struct APIResponse: Codable {
    let metadata: Metadata
    let users: [User]
}
struct Metadata: Codable {
    let currentPage: Int
    let totalPages: Int
    let pageSize: Int
}
```

**Detailed Roadmap for the Weekend Project**

**Day 1: Setup and Basic Socket Server (4--6 hours)**

1.  **Project Setup**:

-   Create a Swift command-line project using Swift Package Manager (SPM) or Xcode.
-   No dependencies are needed; use import Foundation for JSON and GCD, and import Darwin for socket APIs.
-   Create a directory structure:

-   Sources/: Main server code.
-   Tests/: Unit tests for parsing and routing.
-   Data/: Mock user data (e.g., a JSON file or in-memory array).

3.  **Create a TCP Server Socket**:

-   Use Darwin's socket APIs to set up a server:

-   Create a socket: socket(AF_INET, SOCK_STREAM, 0) for IPv4 TCP.
-   Set socket options: setsockopt with SO_REUSEADDR to allow port reuse.
-   Bind to localhost:8080 using a sockaddr_in structure.
-   Call listen with a backlog (e.g., 10 connections).

-   Handle errors (e.g., port in use, permission issues) by logging and exiting gracefully.
-   Learning Goal: Understand socket creation, binding, and listening.

5.  **Accept Connections**:

-   Use accept in a loop to handle incoming client connections, returning a new socket for each client.
-   Test with curl http://localhost:8080 to ensure the server accepts connections (no response yet).

7.  **Mock Data Store**:

-   Create an in-memory array of 50 User structs with varied id, name, and status (e.g., 30 active, 20 inactive).
-   Alternatively, load users from a JSON file using JSONDecoder for persistence.
-   Ensure thread-safe access using a DispatchQueue or Swift's actor model.

9.  **Test and Debug**:

-   Use print statements or a simple logging function to track socket creation and connection acceptance.
-   Test connectivity with curl or a browser to confirm the server is running.

**Day 2: HTTP Request Parsing and Response Generation (6--8 hours)**

1.  **Read Client Data**:

-   For each client socket (from accept), read data using recv into a buffer (e.g., [UInt8]).
-   Process data as a string (convert bytes to UTF-8) to parse the HTTP request.
-   Limit buffer size (e.g., 4096 bytes) to handle typical HTTP requests.

3.  **Parse HTTP Requests**:

-   Parse the request string:

-   Split the first line into method, path, and HTTP version (e.g., GET /users?page=1&size=10 HTTP/1.1).
-   Read headers until an empty line (\r\n\r\n).
-   Ignore the body for GET requests (no body expected).

-   Use URLComponents to parse the path and query parameters:

-   Extract page, size, and status from the query string.
-   Validate parameters (e.g., page and size must be positive integers).

-   Handle malformed requests by preparing a 400 Bad Request response.
-   Learning Goal: Understand HTTP request structure and query parameter parsing.

5.  **Route Requests**:

-   Implement basic routing for:

-   GET /users?page={page}&size={pageSize}&status={status}: Process pagination and filtering.
-   Other paths: Return 404 Not Found.

-   For /users:

-   Filter users by status (if provided) using array filtering.
-   Calculate pagination:

-   totalPages = ceiling(filteredUsers.count / pageSize).
-   Return users for the requested page (e.g., users[(page-1)*size ..< min(page*size, filteredUsers.count)]).

-   Build an APIResponse with metadata and users.

-   Handle edge cases:

-   Invalid page or size: Return 400 Bad Request.
-   Page beyond totalPages: Return empty users array or 404.

7.  **Generate HTTP Responses**:

-   Create a response string:

-   Status line: e.g., HTTP/1.1 200 OK.
-   Headers: Content-Type: application/json, Content-Length: [body length], Connection: close (for simplicity).
-   Body: JSON-encoded APIResponse using JSONEncoder.

-   Convert the response to [UInt8] and send it via send on the client socket.
-   Example response:
```
HTTP/1.1 200 OK
Content-Type: application/json
Content-Length: 123
Connection: close

{
  "metadata": {
    "currentPage": 1,
    "totalPages": 5,
    "pageSize": 10
  },
  "users": [
    {"id": "u1", "name": "Alice", "status": "active"},
    {"id": "u2", "name": "Bob", "status": "active"}
  ]
}
```

-   Learning Goal: Learn HTTP response formatting and JSON serialization.

9.  **Close Client Connections**:

-   Close the client socket after sending the response to free resources.
-   Keep the server socket open for new connections.

11. **Test and Debug**:

-   Use curl to test:
```
curl "http://localhost:8080/users?page=1&size=10"
curl "http://localhost:8080/users?page=1&size=10&status=active"
curl "http://localhost:8080/invalid" # Should return 404
```

-   Verify JSON structure, pagination, and filtering.
-   Log requests and responses (e.g., to console or a file) for debugging.

**Day 3: Concurrency, Error Handling, and Polish (5--7 hours)**

1.  **Add Concurrency**:

-   Modify the accept loop to handle each client connection on a separate DispatchQueue:

```
let queue = DispatchQueue(label: "com.example.server.client", attributes: .concurrent)
while true {
    let clientSocket = accept(serverSocket, ...)
    queue.async {
        // Read, parse, process, and respond
        close(clientSocket)
    }
}
```

-   Use a serial DispatchQueue or actor to protect the user data store from concurrent access.
-   Test with multiple simultaneous curl requests to ensure concurrency works.

3.  **Enhance Error Handling**:

-   Handle socket errors (e.g., recv or send failures) by logging and closing the connection.
-   Return specific HTTP status codes:

-   400 Bad Request: Invalid query parameters (e.g., negative page).
-   404 Not Found: Unknown paths.
-   500 Internal Server Error: Unexpected server issues (e.g., JSON encoding failure).

-   Log errors to a file or console for debugging.

5.  **Add Logging**:

-   Implement a simple logging function to record:

-   Incoming requests (method, path, query parameters).
-   Response status codes and errors.
-   Example: 2025-10-22 14:24: Received GET /users?page=1&size=10, responded with 200 OK.

-   Use FileHandle or console output for logging.

7.  **Support Persistent Connections (Optional)**:

-   Add support for HTTP/1.1 keep-alive (check Connection: keep-alive header).
-   Keep the client socket open to handle multiple requests until the client sends Connection: close or a timeout occurs.
-   This is a stretch goal for deeper HTTP learning.

9.  **Polish the API**:

-   Add a GET / endpoint that returns a simple welcome message (e.g., {"message": "Welcome to the User API"}).
-   Validate query parameters thoroughly (e.g., ensure status is "active", "inactive", or absent).
-   Add a default page=1 and size=10 if query parameters are missing.

11. **Test Extensively**:

-   Test pagination: Fetch pages 1, 2, and beyond totalPages.
-   Test filtering: Use status=active, status=inactive, and no status.
-   Test errors: Invalid paths, malformed query parameters, concurrent requests.
-   Use tools like Postman or a browser to visualize JSON responses.
-   Simulate client load with multiple curl commands or a script.

13. **Optional Integration with Client**:

-   If you've built the paginated user list client from your previous question, test it against your server:

-   Point the client's URLSession to http://localhost:8080/users.
-   Verify the client correctly handles pagination and filtering.
-   Ensure the client's Combine pipeline processes your server's JSON responses.

**Learning Goals for the Weekend**

-   **Socket Programming**: Master low-level socket APIs (socket, bind, listen, accept, recv, send) and understand TCP communication.
-   **HTTP Protocol**: Learn to parse HTTP requests and format responses manually, including headers and status codes.
-   **JSON Handling**: Gain proficiency with Codable, JSONEncoder, and JSONDecoder for API data.
-   **Concurrency**: Understand GCD for handling multiple clients and thread safety for shared data.
-   **Error Handling**: Build robust error handling for network and application errors.
-   **API Design**: Implement a REST-like API with pagination and filtering, aligning with real-world practices.

**Time Breakdown (15--20 Hours)**

-   **Day 1 (4--6 hours)**:

-   Setup project and data model (1 hour).
-   Create and test basic socket server (2--3 hours).
-   Initialize mock user data (1--2 hours).

-   **Day 2 (6--8 hours)**:

-   Implement request parsing (2--3 hours).
-   Build routing and pagination logic (2--3 hours).
-   Generate JSON responses (1--2 hours).
-   Test with curl (1 hour).

-   **Day 3 (5--7 hours)**:

-   Add concurrency with GCD (2 hours).
-   Enhance error handling and logging (2 hours).
-   Polish API and test extensively (1--2 hours).
-   Optional: Add keep-alive or integrate with client (1 hour).

**Simplifications for Manageability**

-   **HTTP/1.1 with Connection: close**: Avoid keep-alive to simplify connection handling (close socket after each response).
-   **GET Only**: Focus on GET requests for /users, ignoring POST or other methods.
-   **In-Memory Data**: Use an array instead of a database to keep data management simple.
-   **Basic Routing**: Support /users and a root endpoint (/), returning 404 for others.
-   **Minimal Headers**: Handle essential headers (Content-Type, Content-Length) in responses.

**Challenges to Explore**

-   **Parsing Edge Cases**: Handle malformed requests (e.g., missing headers, invalid query strings).
-   **Concurrency Issues**: Ensure thread safety for the user data store.
-   **Scalability**: Test how the server handles 10+ simultaneous connections.
-   **Error Recovery**: Recover gracefully from socket failures or client disconnects.
-   **Extensibility**: Design the server to easily add new endpoints (e.g., GET /users/{id}).

**Integration with Paginated User List**

-   **API Compatibility**: Ensure the server's /users endpoint matches the client's expectations:

-   Query parameters: page, size, status.
-   JSON response: { "metadata": { currentPage, totalPages, pageSize }, "users": [{ id, name, status }] }.

-   **Test with Client**: If you have the SwiftUI/Combine client from your previous question, point it to http://localhost:8080/users and verify pagination and filtering work.
-   **Mock Data**: Populate the server with 50--100 users to test pagination (e.g., 5 pages at size=10).
-   **Filtering**: Implement status filtering (active, inactive) to match the client's picker.

**How to Run**
using bash
```
./httpserver
```
