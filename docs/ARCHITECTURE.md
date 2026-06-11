# Architecture

This document describes how HTTPServer is structured and the reasoning behind its
main design choices. The goal of the project is to implement a working HTTP/1.1
server from scratch on Darwin BSD sockets, with no external frameworks, while
keeping the code testable and safe under Swift 6 strict concurrency.

## Request lifecycle

```
main.swift
  builds ServerConfiguration (port, limits, timeouts)
        |
        v
HTTPServer.start()                      (blocking acceptor thread)
  socket -> setsockopt -> bind -> listen
  install SIGINT handler
  while not shutting down:
      accept() ----------------------> new client socket
          |
          v
      Task.detached                      (one async task per connection)
          |
          v
      ConnectionReader.read(from:configuration:)
          recv in a loop, accumulate bytes
          RequestFraming.evaluate(...) decides complete / incomplete / too large / malformed
          |
          v
      ConnectionReader.response(forRawRequest:router:)
          decode UTF-8 -> RequestHandler.parseRequest -> RequestHandler.handleRequest
          |
          v
      UserStore (actor)                  serves paginated, filtered users
          |
          v
      serialize response -> send() -> close socket
```

## Components

| Component | Responsibility |
|-----------|----------------|
| `main.swift` | Builds the configuration from the environment and starts the server. |
| `ServerConfiguration` | Injected settings: port, host, backlog, request size cap, read timeout, and recv chunk size. |
| `HTTPServer` | Owns the listening socket, runs the accept loop, dispatches connections, and handles graceful shutdown. |
| `ConnectionReader` | Reads a full request from a socket and decides its response, with no knowledge of the server lifecycle. |
| `RequestFraming` | Pure, byte level logic that decides whether a complete HTTP message has arrived. |
| `RequestRouting` | Protocol that `HTTPServer` depends on, so the router can be swapped in tests. |
| `RequestHandler` | Parses requests, routes `GET /users` and `GET /`, and serializes responses. |
| `UserStore` | An actor holding the in memory user data and the pagination and filtering logic. |
| `ServerError` | The thrown error type for both fatal startup failures and per connection conditions. |

## Concurrency model

The `accept()` syscall is blocking, so the accept loop deliberately stays out of
structured concurrency and runs on the thread that calls `start()`. Each accepted
connection is handed to its own detached `Task`, which reads, routes, and responds
asynchronously. The client socket descriptor is a plain `Int32` and crosses the
task boundary cleanly, and `HTTPServer` is `Sendable`, so the model is free of data
races under Swift 6 strict concurrency.

A `TaskGroup` was considered and rejected: it would require an async parent scope
and would force the blocking `accept()` into the cooperative thread pool. One
blocking acceptor thread plus many async handlers is the honest match for the
socket lifecycle. The tradeoff is that there is currently no backpressure or
connection cap, which is listed under future work.

## Request framing

Early versions read a single fixed size buffer and decoded it as UTF-8 before
parsing. That truncated requests larger than the buffer, could not handle reads
split across packets, and crashed framing on non text bodies.

`RequestFraming.evaluate` replaces that with pure, byte oriented logic. It looks for
the `\r\n\r\n` header terminator, reads a case insensitive `Content-Length`, and
reports whether the request is complete, still incomplete, too large, or malformed.
Because it is a free function over a byte array, it is exhaustively unit tested
without any sockets, and `ConnectionReader.read` simply loops `recv` and consults it.

## Error model

Fatal startup failures (socket, bind, listen) throw `ServerError` out of `start()`,
and `main.swift` reports them and exits with a failure code rather than calling
`exit(1)` from deep inside the server. Per connection conditions are caught while
handling a single client and translated into HTTP responses: `413` for an oversized
request, `408` for a read timeout, and `400` for unframable or non UTF-8 bytes.

## Graceful shutdown

A `DispatchSourceSignal` traps `SIGINT`. The handler flips a shutdown flag held in
a `Mutex` (from the `Synchronization` module, so `HTTPServer` stays `Sendable`
without `@unchecked`) and closes the listening socket. Closing the socket unblocks
`accept()`, the loop sees the flag and exits, and `start()` returns normally so the
process exits cleanly on `Ctrl+C`.
