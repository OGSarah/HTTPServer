# HTTPServer
![Swift 6+](https://img.shields.io/badge/Swift-6%2B-orange.svg) ![macOS 26](https://img.shields.io/badge/platform-macOS_26-lightgrey.svg)

**A lightweight, educational HTTP server built from scratch in Swift using only the standard library and Darwin socket APIs — no external frameworks.**

This project implements a minimal yet functional HTTP server that serves a **paginated user list API** with filtering, designed specifically for learning low-level networking, HTTP protocol handling, and concurrency in Swift.

| Features |
|-------|
| TCP socket server (`socket`, `bind`, `listen`, `accept`) |
| HTTP/1.1 request parsing (method, path, query params, headers) |
| Pagination (`page`, `size`) |
| Filtering (`status=active` or `inactive`) |
| Thread-safe in-memory user store (`actor`) |
| Concurrent client handling (`DispatchQueue`) |
| JSON encoding/decoding (`Codable`) |
| Error handling (400, 404, 500) |
| Request/response logging |
| Command-line executable |

---

#### 

#### Project Layout:
```
HTTPServer/
├── HTTPServer/
│   ├── APIResponse.swift
│   ├── HTTPRequest.swift
│   ├── HTTPResponse.swift
│   ├── Metadata.swift
│   ├── User.swift
│   ├── HTTPServer.swift
│   ├── Logger.swift
│   ├── main.swift
│   ├── RequestHandler.swift
│   └── UserStore.swift
```

#### API Endpoint:

`GET /users?page={page}&size={size}&status={status}`

#### Response Format:
```bash
{
  "metadata": {
    "currentPage": 1,
    "totalPages": 5,
    "pageSize": 10
  },
  "users": [
    { "id": "u1", "name": "Orko 1", "status": "inactive" },
    { "id": "u2", "name": "Molly 2", "status": "active" }
  ]
}

```

#### Root Endpoint:
```bash
curl http://localhost:8080/
```

```bash
{ "message": "Welcome to the User API" }
```

#### Query Parameters:
| Param | Type | Default | Description |
|------|------|--------|-------------|
| `page` | `Int` | `1` | Current page |
| `size` | `Int` | `10` | Items per page |
| `status` | `String` | `nil` | Filter: `active` or `inactive` |

#### Example Requests:
```bash
curl "http://localhost:8080/users?page=1&size=5"
curl "http://localhost:8080/users?page=2&size=10&status=active"
```

#### Sample Console Output:
```
[2025-11-03 14:22:10] Server started on port 8080
[2025-11-03 14:22:15] GET /users?page=1&size=10&status=active → 200 OK
[2025-11-03 14:22:18] GET /invalid → 404 Not Found
[2025-11-03 14:22:20] Invalid query: page=-1 → 400 Bad Request

```
# Build and Run

#### Prerequisites:
- Xcode 26
- macOS 26 or later


#### Compile
Navigate to the HTTPServer that is adjacent to the HTTPServer.xcodeproj in the folder structure. Then run:

```
swiftc *.swift -o httpserver
```
#### Run
```bash
./httpserver
```

#### Test
```
# Basic request
curl "http://localhost:8080/users?page=1&size=5"

# Filtered request
curl "http://localhost:8080/users?page=1&size=10&status=active"

# Welcome page
curl http://localhost:8080/

# Error cases
curl "http://localhost:8080/invalid"        # 404
curl "http://localhost:8080/users?page=-1"  # 400
```
#### Stop
Press `Ctrl + C`

## License
Proprietary Software

© 2026 SarahUniverse

This software and its source code are the exclusive property of SarahUniverse.
No part of this software may be reproduced, distributed, or transmitted in any form or by any means without prior written permission.
