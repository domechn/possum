import SwiftUI

struct ScreensaverView: View {
    @EnvironmentObject var hintState: HintState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var now = Date()
    @State private var drift = CGSize.zero

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 16) {
                Text(ClockFormatter.timeString(from: now))
                    .font(.system(size: 160, weight: .ultraLight, design: .default))
                    .foregroundStyle(.white)
                    .kerning(-3)
                Text(ClockFormatter.dateString(from: now))
                    .font(.system(size: 26, weight: .light))
                    .foregroundStyle(.white.opacity(0.55))

                HintView()
                    .environmentObject(hintState)
                    .frame(height: 90)
                    .padding(.top, 20)
                    .opacity(hintState.visible ? 1 : 0)
                    .animation(.easeInOut(duration: 0.4), value: hintState.visible)
            }
            .offset(drift)
        }
        .onReceive(timer) { date in
            let minuteChanged = Calendar.current.component(.minute, from: date)
                != Calendar.current.component(.minute, from: now)
            now = date
            if minuteChanged && !reduceMotion {
                withAnimation(.easeInOut(duration: 3)) {
                    drift = CGSize(width: CGFloat.random(in: -40...40),
                                   height: CGFloat.random(in: -20...20))
                }
            }
        }
    }
}

struct HintView: View {
    @EnvironmentObject var hintState: HintState

    var body: some View {
        VStack(spacing: 16) {
            Text("按住 Esc 或点击按钮退出")
                .font(.system(size: 14, weight: .light))
                .foregroundStyle(.white.opacity(0.35))

            Capsule()
                .fill(.white.opacity(0.08))
                .frame(width: 180, height: 3)
                .overlay(alignment: .leading) {
                    Capsule()
                        .fill(.white.opacity(0.6))
                        .frame(width: max(0, 180 * hintState.escProgress), height: 3)
                        .animation(.linear(duration: 0.05), value: hintState.escProgress)
                }

            Button {
                NotificationCenter.default.post(name: .exitScreensaverRequested, object: nil)
            } label: {
                Text("退出")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(.white.opacity(0.4))
                    .padding(.horizontal, 18)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .stroke(.white.opacity(0.15), lineWidth: 0.5)
                    )
            }
            .buttonStyle(.plain)
        }
    }
}

extension Notification.Name {
    static let exitScreensaverRequested = Notification.Name("exitScreensaverRequested")
}
