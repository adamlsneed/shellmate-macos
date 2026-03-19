import SwiftUI
struct LoadingSpinner: View {
    @State private var isAnimating = false
    var body: some View {
        Circle().trim(from: 0, to: 0.7).stroke(ShellmateColors.accent, lineWidth: 3).frame(width: 24, height: 24)
            .rotationEffect(.degrees(isAnimating ? 360 : 0))
            .animation(.linear(duration: 0.8).repeatForever(autoreverses: false), value: isAnimating)
            .onAppear { isAnimating = true }
    }
}
struct BouncingDots: View {
    @State private var animating = false
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { i in
                Circle().fill(ShellmateColors.shell400).frame(width: 8, height: 8)
                    .offset(y: animating ? -4 : 4)
                    .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true).delay(Double(i) * 0.15), value: animating)
            }
        }.onAppear { animating = true }
    }
}
