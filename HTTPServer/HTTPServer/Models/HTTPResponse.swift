//
//  HTTPResponse.swift
//  HTTPServer
//
//  Created by Sarah Clark on 10/23/25.
//

import Foundation

struct HTTPResponse {
    let statusCode: Int
    let statusText: String
    let headers: [String: String]
    let body: Data?
}
