//
//  UserModel.swift
//  HTTPServer
//
//  Created by Sarah Clark on 10/22/25.
//

import Foundation

struct User: Codable {
    let id: String
    let name: String
    let status: String // "active" or "inactive"
}
