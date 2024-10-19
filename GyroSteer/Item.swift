//
//  Item.swift
//  GyroSteer
//
//  Created by Christina Lark on 10/19/24.
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
