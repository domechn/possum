import SwiftUI

struct ContentView: View {
    @EnvironmentObject var session: SessionController
    @State private var delaySeconds = 5
    @State private var isHovering = false

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.4)
            content
            Spacer(minLength: 12)
            footer
        }
        .padding(.vertical, 28)
        .padding(.horizontal, 36)
        .frame(width: 380)
        .background(.background)
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 6) {
            Text("Possum")
                .font(.system(size: 26, weight: .semibold, design: .rounded))
            Text("假寐 — 防休眠 + 仿屏保")
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(.secondary)
        }
        .padding(.bottom, 20)
    }

    // MARK: - Content (state-driven)

    @ViewBuilder
    private var content: some View {
        switch session.state {
        case .idle:
            idleView
        case .countingDown(let remaining):
            countdownView(remaining: remaining)
        case .active:
            activeView
        }
    }

    private var idleView: some View {
        VStack(spacing: 20) {
            Form {
                Section {
                    Stepper("延时 \(delaySeconds) 秒", value: $delaySeconds, in: 0...30)
                }

                Section {
                    Toggle(isOn: $session.guardedExitEnabled) {
                        Text("防误触模式")
                    }
                }
            }
            .formStyle(.grouped)
            .scrollDisabled(true)
            .frame(height: 132)

            Button {
                session.startWorkMode(delaySeconds: delaySeconds)
            } label: {
                Text("开始工作模式")
                    .font(.system(size: 14, weight: .medium))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(.accentColor)
            .onHover { isHovering = $0 }
            .scaleEffect(isHovering ? 1.02 : 1.0)
            .animation(.easeOut(duration: 0.15), value: isHovering)

            if let summary = session.lastSessionSummary {
                Label(summary, systemImage: "checkmark.circle")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }

            if let error = session.errorMessage {
                Label(error, systemImage: "exclamationmark.triangle")
                    .font(.system(size: 12))
                    .foregroundStyle(.red)
            }
        }
        .padding(.top, 16)
    }

    private func countdownView(remaining: Int) -> some View {
        VStack(spacing: 20) {
            Spacer(minLength: 20)
            Text("\(remaining)")
                .font(.system(size: 64, weight: .thin, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText())
                .foregroundStyle(.primary)
            Text("秒后进入屏保")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
            Button("取消") {
                session.cancelCountdown()
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)
            Spacer(minLength: 20)
        }
        .padding(.top, 16)
    }

    private var activeView: some View {
        VStack(spacing: 12) {
            Spacer(minLength: 20)
            Image(systemName: "moon.zzz.fill")
                .font(.system(size: 32))
                .foregroundStyle(.tertiary)
            Text("工作模式进行中")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
            Spacer(minLength: 20)
        }
        .padding(.top, 16)
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(spacing: 2) {
            Text("屏保不是锁屏，他人仍可操作这台电脑")
            Text("合盖仍会休眠，请保持开盖")
        }
        .font(.system(size: 11))
        .foregroundStyle(.quaternary)
    }
}
