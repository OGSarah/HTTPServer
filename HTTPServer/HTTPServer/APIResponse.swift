//
//  APIResponse.swift
//  HTTPServer
//
//  Created by Sarah Clark on 10/22/25.
//

import Foundation

struct APIResponse: Codable {
    let metadata: Metadata
    let users: [User]
}
