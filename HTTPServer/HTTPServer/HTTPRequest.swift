//
//  HTTPRequest.swift
//  HTTPServer
//
//  Created by Sarah Clark on 10/23/25.
//

import Foundation

struct HTTPRequest {
    let method: String
    let path: String
    let queryParameters: [String: String]
    let headers: [String: String]
}
