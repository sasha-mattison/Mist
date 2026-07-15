import SwiftUI

/// App-wide motion & flair, all gated by SettingsStore.animationsEnabled so
/// the whole layer can be switched off from Settings. Every effect degrades
/// to a static, fully-visible state when disabled.

// MARK: - Staggered entrance

private struct EntranceEffect: ViewModifier {
    let index: Int
    let enabled: Bool

    @ViewState private var hasAppeared = false

    func body(content: Content) -> some View {
        content
            .opacity(hasAppeared ? 1 : 0)
            .offset(y: hasAppeared ? 0 : 16)
            .scaleEffect(hasAppeared ? 1 : 0.97)
            .onAppear {
                guard enabled else {
                    hasAppeared = true
                    return
                }
                // Modulo keeps the stagger tight while scrolling a lazy grid:
                // freshly materialized rows animate as a small wave, not a
                // minutes-long queue.
                let delay = Double(index % 12) * 0.045
                withAnimation(.spring(response: 0.55, dampingFraction: 0.8).delay(delay)) {
                    hasAppeared = true
                }
            }
    }
}

extension View {
    /// Fade-rise entrance on first appearance, staggered by `index`.
    func entranceEffect(index: Int = 0, enabled: Bool = true) -> some View {
        modifier(EntranceEffect(index: index, enabled: enabled))
    }
}

// MARK: - Pointer-following 3D tilt

private struct HoverTilt: ViewModifier {
    let enabled: Bool
    let maxDegrees: Double

    @ViewState private var tilt: CGSize = .zero
    @ViewState private var size: CGSize = .zero

    func body(content: Content) -> some View {
        content
            .rotation3DEffect(.degrees(tilt.height * maxDegrees), axis: (x: 1, y: 0, z: 0))
            .rotation3DEffect(.degrees(tilt.width * maxDegrees), axis: (x: 0, y: 1, z: 0))
            .onGeometryChange(for: CGSize.self) { $0.size } action: { size = $0 }
            .onContinuousHover(coordinateSpace: .local) { phase in
                guard enabled else { return }
                switch phase {
                case .active(let location):
                    let nx = (location.x / max(size.width, 1)) - 0.5
                    let ny = (location.y / max(size.height, 1)) - 0.5
                    withAnimation(.interactiveSpring(response: 0.25, dampingFraction: 0.85)) {
                        tilt = CGSize(width: nx * 2, height: -ny * 2)
                    }
                case .ended:
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) {
                        tilt = .zero
                    }
                }
            }
    }
}

extension View {
    /// Tilts the view in 3D toward the pointer while hovered.
    func hoverTilt(enabled: Bool, maxDegrees: Double = 6) -> some View {
        modifier(HoverTilt(enabled: enabled, maxDegrees: maxDegrees))
    }
}

// MARK: - Shine sweep

private struct ShineSweep: ViewModifier {
    /// Sweeps once each time this flips to true (e.g. hover start).
    let trigger: Bool
    let enabled: Bool

    @ViewState private var phase: CGFloat = -1

    func body(content: Content) -> some View {
        content
            .overlay {
                if enabled {
                    GeometryReader { geo in
                        LinearGradient(
                            stops: [
                                .init(color: .clear, location: 0.38),
                                .init(color: .white.opacity(0.22), location: 0.5),
                                .init(color: .clear, location: 0.62)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .frame(width: geo.size.width * 2, height: geo.size.height * 2)
                        .offset(
                            x: phase * geo.size.width * 1.2 - geo.size.width / 2,
                            y: phase * geo.size.height * 1.2 - geo.size.height / 2
                        )
                    }
                    .allowsHitTesting(false)
                }
            }
            .onChange(of: trigger) { _, active in
                guard enabled, active else { return }
                phase = -1
                withAnimation(.easeOut(duration: 0.8)) { phase = 1 }
            }
    }
}

extension View {
    /// A glossy highlight that sweeps across once whenever `trigger` becomes
    /// true. Apply before clipping so the band stays inside the shape.
    func shineSweep(trigger: Bool, enabled: Bool) -> some View {
        modifier(ShineSweep(trigger: trigger, enabled: enabled))
    }
}

// MARK: - Ambient accent background

/// Slow-drifting blurred accent blobs behind content — the "tinted
/// background" setting. Blobs are static (but still tinted) when animations
/// are off.
struct AmbientAccentBackground: View {
    let accent: Color
    let animated: Bool

    @ViewState private var drift = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                blob(diameter: geo.size.width * 0.72, opacity: 0.12)
                    .offset(
                        x: drift ? geo.size.width * 0.28 : -geo.size.width * 0.22,
                        y: drift ? -geo.size.height * 0.18 : geo.size.height * 0.12
                    )
                    .animation(driftAnimation(duration: 24), value: drift)
                blob(diameter: geo.size.width * 0.5, opacity: 0.09)
                    .offset(
                        x: drift ? -geo.size.width * 0.3 : geo.size.width * 0.34,
                        y: drift ? geo.size.height * 0.3 : -geo.size.height * 0.08
                    )
                    .animation(driftAnimation(duration: 31), value: drift)
                blob(diameter: geo.size.width * 0.38, opacity: 0.07)
                    .offset(
                        x: drift ? geo.size.width * 0.05 : -geo.size.width * 0.1,
                        y: drift ? geo.size.height * 0.35 : geo.size.height * 0.05
                    )
                    .animation(driftAnimation(duration: 19), value: drift)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
        .onAppear { drift = animated }
        .onChange(of: animated) { _, on in drift = on }
    }

    private func driftAnimation(duration: Double) -> Animation {
        animated
            ? .easeInOut(duration: duration).repeatForever(autoreverses: true)
            : .easeOut(duration: 0.6)
    }

    private func blob(diameter: CGFloat, opacity: Double) -> some View {
        Circle()
            .fill(accent.opacity(opacity))
            .frame(width: diameter, height: diameter)
            .blur(radius: 90)
    }
}

// MARK: - Avatar glow ring

/// Rotating angular-gradient ring with a soft glow, wrapped around a
/// circular avatar.
struct AvatarGlowRing<Content: View>: View {
    let accent: Color
    let animated: Bool
    var lineWidth: CGFloat = 3
    @ViewBuilder let content: Content

    @ViewState private var spin = false

    var body: some View {
        content
            .padding(lineWidth + 4)
            .background {
                Circle()
                    .strokeBorder(
                        AngularGradient(
                            colors: [accent, accent.opacity(0.12), accent.opacity(0.6), accent],
                            center: .center
                        ),
                        lineWidth: lineWidth
                    )
                    .rotationEffect(.degrees(spin ? 360 : 0))
                    .animation(
                        animated
                            ? .linear(duration: 6).repeatForever(autoreverses: false)
                            : .default,
                        value: spin
                    )
                    .shadow(color: accent.opacity(0.45), radius: 10)
            }
            .onAppear { spin = animated }
            .onChange(of: animated) { _, on in spin = on }
    }
}

// MARK: - Stretchy / parallax scroll header

private struct ParallaxStretchHeader: ViewModifier {
    let height: CGFloat
    let enabled: Bool

    /// Extra vertical bleed so the parallax slide never exposes an edge.
    private var bleed: CGFloat { enabled ? 70 : 0 }

    func body(content: Content) -> some View {
        GeometryReader { geo in
            let minY = enabled ? geo.frame(in: .scrollView(axis: .vertical)).minY : 0
            let stretch = max(0, minY)
            let slide = min(bleed, max(-bleed, -minY * 0.35))
            content
                .frame(width: geo.size.width, height: height + bleed * 2 + stretch)
                .offset(y: -bleed - stretch / 2 + (minY < 0 ? slide : 0))
        }
        .frame(height: height)
        .clipped()
    }
}

extension View {
    /// Hero-header treatment: stretches with top overscroll and scrolls at
    /// reduced speed (parallax). Must live inside a ScrollView.
    func parallaxStretchHeader(height: CGFloat, enabled: Bool) -> some View {
        modifier(ParallaxStretchHeader(height: height, enabled: enabled))
    }
}
