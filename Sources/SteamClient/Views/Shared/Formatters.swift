import Foundation

enum Formatters {
    static let size: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter
    }()

    static let lastPlayed: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter
    }()

    /// Storefront prices arrive as integer cents plus an ISO currency code.
    static func price(cents: Int, currencyCode: String?) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode ?? "USD"
        return formatter.string(from: NSNumber(value: Double(cents) / 100))
            ?? String(format: "%.2f", Double(cents) / 100)
    }

    static func playtime(minutes: Int) -> String {
        if minutes <= 0 { return "—" }
        if minutes < 60 { return "\(minutes) min" }
        let hours = Double(minutes) / 60
        if hours < 100 {
            return String(format: "%.1f hrs", hours)
        }
        return "\(Int(hours.rounded())) hrs"
    }
}
