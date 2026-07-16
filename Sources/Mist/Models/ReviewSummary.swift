import Foundation

/// Aggregate review summary from the storefront's unauthenticated
/// `appreviews` endpoint — decoupled from `GameDetails` since it's a
/// separate call (SteamStoreClient.reviewSummary(for:)).
struct ReviewSummary: Decodable, Hashable {
    let reviewScoreDescription: String
    let totalPositive: Int
    let totalNegative: Int
    let totalReviews: Int

    enum CodingKeys: String, CodingKey {
        case reviewScoreDescription = "review_score_desc"
        case totalPositive = "total_positive"
        case totalNegative = "total_negative"
        case totalReviews = "total_reviews"
    }

    var positivePercent: Int? {
        guard totalReviews > 0 else { return nil }
        return Int((Double(totalPositive) / Double(totalReviews) * 100).rounded())
    }
}
