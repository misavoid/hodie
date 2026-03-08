import SwiftUI

extension Binding where Value == Date {
    init(_ source: Binding<Date?>, default defaultValue: Date) {
        self.init(
            get: { source.wrappedValue ?? defaultValue },
            set: { newValue in source.wrappedValue = newValue }
        )
    }
}
