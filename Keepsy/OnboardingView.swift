import SwiftUI
import UserNotifications

/// First launch: the gestures nobody finds on their own, then the daily reminder.
struct OnboardingView: View {
    let finish: () -> Void

    @AppStorage(Reminders.minutesKey) private var minutes = Reminders.defaultMinutes
    @State private var page = 0
    private let lastPage = 3

    var body: some View {
        VStack(spacing: 16) {
            TabView(selection: $page.animation()) {
                Tip(title: "Swipe when things change", message: "Swipe left when you finish something. Swipe right when you buy it again, and Keepsy fills in where it goes and how long it lasts.") {
                    VStack(spacing: 10) {
                        Image(.milk).illustration(height: 170)
                        MockRow(name: "Milk", days: 2)
                        HStack {
                            SwipeHint(title: "Bought Again", systemImage: "arrow.clockwise", color: .accentColor)
                            Spacer()
                            SwipeHint(title: "Used", systemImage: "checkmark", color: .fresh)
                        }
                    }
                }
                .tag(0)
                Tip(title: "Hold for more", message: "Touch and hold an item to change how much is left, move it to the freezer, or mark it as thrown away.") {
                    VStack(alignment: .leading, spacing: 10) {
                        Image(.fridge).illustration(height: 130)
                            .frame(maxWidth: .infinity)
                        MockRow(name: "Spinach", days: 1)
                        VStack(alignment: .leading, spacing: 0) {
                            MenuLine(title: "Remaining", systemImage: "gauge.with.dots.needle.50percent")
                            Divider()
                            MenuLine(title: "Freeze", systemImage: "snowflake")
                            Divider()
                            MenuLine(title: "Threw Away", systemImage: "trash")
                        }
                        .background(.background, in: .rect(cornerRadius: 14))
                        .frame(maxWidth: 240)
                    }
                }
                .tag(1)
                Tip(title: "Scan the date", message: "Point the camera at the package and Keepsy reads the expiration date for you.") {
                    Image(.scan).illustration(height: 240)
                }
                .tag(2)
                Tip(title: "A nudge each morning", message: "Get one notification a day with what runs out soon. Pick a time; you can change it later in Settings.") {
                    VStack(spacing: 16) {
                        Image(.clock).illustration(height: 150)
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "bell.badge.fill")
                                .foregroundStyle(Color.accentColor)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Expiring soon")
                                    .font(.subheadline.weight(.semibold))
                                Text(verbatim: "Milk D-Day, Tofu D-2, Eggs D-5")
                                    .font(.subheadline)
                            }
                            Spacer()
                        }
                        .padding()
                        .background(.background, in: .rect(cornerRadius: 18))
                        .accessibilityHidden(true)
                        DatePicker("Time", selection: ReminderTime.binding($minutes), displayedComponents: .hourAndMinute)
                            .datePickerStyle(.compact)
                    }
                }
                .tag(lastPage)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            VStack(spacing: 8) {
                Button {
                    if page < lastPage {
                        withAnimation { page += 1 }
                    } else {
                        Task {
                            _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
                            finish()
                        }
                    }
                } label: {
                    Text(page < lastPage ? "Next" : "Turn On Reminders")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                Button(page < lastPage ? "Skip" : "Not Now", action: finish)
                    .font(.subheadline)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 8)
        }
        .background(Color(.systemGroupedBackground))
    }
}

private struct Tip<Illustration: View>: View {
    let title: LocalizedStringResource
    let message: LocalizedStringResource
    @ViewBuilder let illustration: Illustration

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Spacer(minLength: 0)
            illustration
                .frame(maxWidth: .infinity)
            Spacer(minLength: 0)
            VStack(alignment: .leading, spacing: 10) {
                Text(title)
                    .font(.stamp(.title2))
                Text(message)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 28)
        .padding(.bottom, 48)
    }
}

private struct MockRow: View {
    let name: LocalizedStringResource
    let days: Int

    var body: some View {
        HStack {
            Text(name)
                .font(.body.weight(.semibold))
            Spacer()
            Text(Expiry.label(daysLeft: days))
                .font(.stamp(.title3))
                .foregroundStyle(Expiry.color(daysLeft: days))
        }
        .padding()
        .background(.background, in: .rect(cornerRadius: 14))
        .accessibilityHidden(true)
    }
}

private struct SwipeHint: View {
    let title: LocalizedStringResource
    let systemImage: String
    let color: Color

    var body: some View {
        Label { Text(title) } icon: { Image(systemName: systemImage) }
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .foregroundStyle(Color(.systemBackground))
            .background(color, in: .capsule)
            .accessibilityHidden(true)
    }
}

private struct MenuLine: View {
    let title: LocalizedStringResource
    let systemImage: String

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Image(systemName: systemImage)
        }
        .font(.subheadline)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .accessibilityHidden(true)
    }
}

#Preview {
    OnboardingView {}
}
