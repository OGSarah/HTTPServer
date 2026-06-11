# Contributing

Thanks for taking a look at HTTPServer. This is a small, focused project, so the
guidelines are short.

## Principles

- No external frameworks. The point of the project is to build an HTTP/1.1 server
  from scratch on the standard library and Darwin socket APIs. Please keep new code
  framework free.
- Keep socket I/O separate from logic. Framing and routing decisions live in pure,
  testable types (`RequestFraming`, `ConnectionReader.response`); sockets stay in
  `HTTPServer` and `ConnectionReader.read`.
- Documentation and comments do not use em dashes. Use commas, colons, or reworded
  sentences instead.

## Building

Open `HTTPServer/HTTPServer.xcodeproj` in Xcode 26, or build the command line tool
directly:

```bash
cd HTTPServer/HTTPServer
swiftc *.swift -o httpserver
```

## Running the tests

The test suite uses Swift Testing. Run it from Xcode, or from the command line the
same way CI does:

```bash
xcodebuild test \
  -project HTTPServer/HTTPServer.xcodeproj \
  -scheme HTTPServer \
  -destination 'platform=macOS'
```

## Linting

The project is linted with [SwiftLint](https://github.com/realm/SwiftLint). Install
it with `brew install swiftlint`, then run:

```bash
swiftlint lint --strict
```

The lint job runs separately from the test job in CI, so a style warning never
blocks the test results.
