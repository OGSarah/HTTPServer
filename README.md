# HTTPServer
[![Tests](https://github.com/OGSarah/HTTPServer/actions/workflows/tests.yml/badge.svg)](https://github.com/OGSarah/HTTPServer/actions/workflows/tests.yml) [![Lint](https://github.com/OGSarah/HTTPServer/actions/workflows/lint.yml/badge.svg)](https://github.com/OGSarah/HTTPServer/actions/workflows/lint.yml) ![Swift 6+](https://img.shields.io/badge/Swift-6%2B-orange.svg) ![macOS 26](https://img.shields.io/badge/platform-macOS_26-lightgrey.svg)

A lightweight HTTP/1.1 server built from scratch in Swift using only the standard library and Darwin socket APIs, with no external frameworks.

The project implements a small but complete server that exposes a paginated user list API with filtering. It is written to demonstrate low level networking, HTTP protocol handling, and safe concurrency in Swift 6, while keeping the code testable end to end.

## Features

| Feature | Detail |
|---------|--------|
| TCP socket server | `socket`, `bind`, `listen`, `accept` on Darwin BSD sockets |
| HTTP/1.1 request parsing | method, path, query parameters, and headers |
| Robust request reads | accumulates bytes until the message is complete, handling large and fragmented requests |
| Request size limits | rejects oversized requests with `413 Payload Too Large` |
| Read timeouts | stalled clients are cut off with `408 Request Timeout` |
| Pagination | `page` and `size` query parameters |
| Filtering | `status=active` or `status=inactive` |
| Thread safe data store | an `actor` guards the in memory users |
| Structured concurrency | one blocking acceptor thread, one detached task per connection |
| Graceful shutdown | `SIGINT` closes the listening socket and exits cleanly |
| JSON encoding and decoding | `Codable` models |
| Configurable | port and host via environment variables |
| Command line executable | runs as a standalone tool |

## Architecture

At a high level, `main` builds a `ServerConfiguration`, `HTTPServer` opens the
listening socket and runs a blocking accept loop, and each connection is dispatched
to its own detached `Task`. That task reads the request, frames the bytes with
`RequestFraming`, routes it through `RequestHandler`, and serves data from the
`UserStore` actor. For the full request lifecycle, component responsibilities, and
the reasoning behind the concurrency and error handling choices, see
[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

## Design decisions

A few choices are worth calling out, because they are the difference between a toy
and something closer to production quality:

- Reading uses a loop that accumulates bytes until a complete HTTP message has
  arrived, rather than a single fixed size read. The framing logic is a pure,
  byte level function (`RequestFraming`) so it is exhaustively unit tested without
  binding a port.
- The blocking `accept()` call stays on a dedicated acceptor thread, and each
  connection runs in a detached `Task`. A `TaskGroup` was rejected because it would
  force the blocking accept into the cooperative thread pool.
- A read timeout (`SO_RCVTIMEO`) and a request size cap protect the server from
  slow or oversized clients.
- Startup failures throw a `ServerError` out of `start()` instead of calling
  `exit` from inside the server, so the entry point owns the exit behavior.
- Shutdown state is held in a `Mutex` from the `Synchronization` module, so the
  server type is genuinely `Sendable` under Swift 6 strict concurrency.

## API

### List users

```
GET /users?page={page}&size={size}&status={status}
```

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `page` | `Int` | `1` | Current page |
| `size` | `Int` | `10` | Items per page |
| `status` | `String` | none | Filter by `active` or `inactive` |

Response:

```json
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

### Welcome

```
GET /
```

```json
{ "message": "Welcome to the User API" }
```

### Status codes

| Code | When |
|------|------|
| `200 OK` | A valid request was served |
| `400 Bad Request` | The request could not be parsed or had invalid parameters |
| `404 Not Found` | The path is not handled |
| `405 Method Not Allowed` | The method is not `GET` |
| `408 Request Timeout` | The client stalled before completing the request |
| `413 Payload Too Large` | The request exceeded the configured size limit |
| `500 Internal Server Error` | The response could not be encoded |

### Example requests

```bash
curl "http://localhost:8080/users?page=1&size=5"
curl "http://localhost:8080/users?page=2&size=10&status=active"
curl "http://localhost:8080/"
```

### Sample console output

```
[2026-06-11 14:22:10] Server started on port 8080
[2026-06-11 14:22:15] Responding to GET /users?page=1&size=10&status=active with 200 OK
[2026-06-11 14:22:18] Invalid path: /invalid
[2026-06-11 14:22:20] Invalid query parameters: page=-1, size=10
```

## Configuration

The server reads two environment variables, falling back to the defaults below.

| Variable | Default | Description |
|----------|---------|-------------|
| `PORT` | `8080` | The TCP port to listen on |
| `HOST` | `0.0.0.0` | The host the server reports itself as serving |

Additional limits (request size cap, read timeout, backlog, and recv chunk size)
are defined on `ServerConfiguration` with sensible defaults.

## Build and run

### Prerequisites

- Xcode 26
- macOS 26 or later

### Compile

From the `HTTPServer` folder next to `HTTPServer.xcodeproj`:

```bash
swiftc *.swift -o httpserver
```

### Run

```bash
./httpserver
```

Or run on a different port:

```bash
PORT=9090 ./httpserver
```

Press `Ctrl + C` to stop the server. It closes the listening socket and exits
cleanly.

## Testing

The suite is written with the Swift Testing framework and covers request framing,
parsing, routing, response serialization, the socket read loop (over a `socketpair`),
the data store, and concurrent access. Run it from Xcode, or from the command line:

```bash
xcodebuild test \
  -project HTTPServer/HTTPServer.xcodeproj \
  -scheme HTTPServer \
  -destination 'platform=macOS'
```

## Limitations

- Handles `GET` requests only.
- Responds with `Connection: close`, so there is no HTTP keep alive.
- Data is held in memory and is not persisted.
- No TLS.
- No connection cap or backpressure under heavy load.

## Future work

- HTTP keep alive and persistent connections.
- Binding to a specific host rather than all interfaces.
- A configurable connection limit.
- TLS support.

## License

Released under the [MIT License](LICENSE). © 2026 SarahUniverse
