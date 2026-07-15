import SwiftUI

struct GameCardSkeletonView: View {
    @ViewState private var isAnimating = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.quaternary)
                .frame(width: 200, height: 300)
                .overlay(shimmer)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            RoundedRectangle(cornerRadius: 4)
                .fill(.quaternary)
                .frame(width: 140, height: 14)
        }
        .frame(width: 200)
        .onAppear {
            withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
                isAnimating = true
            }
        }
    }

    private var shimmer: some View {
        GeometryReader { proxy in
            LinearGradient(
                colors: [.clear, .white.opacity(0.25), .clear],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: proxy.size.width * 0.6)
            .offset(x: isAnimating ? proxy.size.width : -proxy.size.width)
        }
    }
}
