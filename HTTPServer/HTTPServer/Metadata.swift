//
//  MetaDataModel.swift
//  HTTPServer
//
//  Created by Sarah Clark on 10/22/25.
//

import Foundation

struct Metadata: Codable {
    let currentPage: Int
    let totalPages: Int
    let pageSize: Int
}
