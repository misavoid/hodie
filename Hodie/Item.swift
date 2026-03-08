//
//  Item.swift
//  Hodie
//
//  Created by Misa Nthrop on 08.03.26.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
