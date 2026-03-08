import Foundation
import UniformTypeIdentifiers
import SwiftUI

extension UTType {
    static let hodieTaskIdentifier = UTType(exportedAs: "com.hodie.task")
}

struct TaskDragItem: Identifiable, Codable, Transferable {
    let id: UUID

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .hodieTaskIdentifier)
    }
}
