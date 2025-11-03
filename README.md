# HTTPServer
[![Swift 5.9+](https://img.shields.io/badge/Swift-5.9%2B-orange.svg)](https://swift.org) [![macOS](https://img.shields.io/badge/platform-macOS-lightgrey.svg)](https://developer.apple.com/macos/)

**A lightweight, educational HTTP server built from scratch in Swift using only the standard library and Darwin socket APIs — no external frameworks.**

This project implements a minimal yet functional HTTP server that serves a **paginated user list API** with filtering, designed specifically for learning low-level networking, HTTP protocol handling, and concurrency in Swift.

---

## Goal

Build a **custom HTTP server** that:
- Listens on `localhost:8080`
- Handles `GET /users` with pagination and status filtering
- Returns JSON responses with proper metadata
- Supports multiple concurrent clients
- Uses **only** `Foundation`, `Darwin`, and Swift’s concurrency (`actor`, GCD)

Perfect for a **long weekend project (15–20 hours)** to deeply understand how web servers work under the hood.

---

## Features

| Feature | Implemented |
|-------|-------------|
| TCP socket server (`socket`, `bind`, `listen`, `accept`) | Yes |
| HTTP/1.1 request parsing (method, path, query params, headers) | Yes |
| Pagination (`page`, `size`) | Yes |
| Filtering (`status=active` or `inactive`) | Yes |
| Thread-safe in-memory user store (`actor`) | Yes |
| Concurrent client handling (`DispatchQueue`) | Yes |
| JSON encoding/decoding (`Codable`) | Yes |
| Error handling (400, 404, 500) | Yes |
| Request/response logging | Yes |
| Command-line executable | Yes |

---

## API Endpoint

`GET /users?page={page}&size={size}&status={status}`

## Response Format
```bash
{
  "metadata": {
    "currentPage": 1,
    "totalPages": 5,
    "pageSize": 10
  },
  "users": [
    { "id": "u1", "name": "Alice 1", "status": "inactive" },
    { "id": "u2", "name": "Bob 2", "status": "active" }
  ]
}

```

### Root Endpoint
```bash
curl http://localhost:8080/
```

```bash
{ "message": "Welcome to the User API" }
```

#### Query Parameters
| Param | Type | Default | Description |
|------|------|--------|-------------|
| `page` | `Int` | `1` | Current page |
| `size` | `Int` | `10` | Items per page |
| `status` | `String` | `nil` | Filter: `active` or `inactive` |

#### Example Requests
```bash
curl "http://localhost:8080/users?page=1&size=5"
curl "http://localhost:8080/users?page=2&size=10&status=active"
```

**How to Run**
using bash
```
./httpserver
```
