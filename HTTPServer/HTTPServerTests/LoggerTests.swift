//
//  LoggerTests.swift
//  HTTPServerTests
//
//  Smoke tests exercising the Logger code path.
//

import Foundation
import Testing

@Suite("Logger")
struct LoggerTests {

    @Test("Logging a message does not crash")
    func logsWithoutCrashing() {
        Logger.log("Test log message")
        Logger.log("")
    }
}
