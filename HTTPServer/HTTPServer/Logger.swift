//
//  Logger.swift
//  HTTPServer
//
//  Created by Sarah Clark on 10/22/25.
//

import Foundation

struct Logger {
    static func log(_ message: String) {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let timestamp = dateFormatter.string(from: Date())
        print("[\(timestamp)] \(message)")
    }

}
