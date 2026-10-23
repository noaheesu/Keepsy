import StoreKit
import SwiftUI
import UserNotifications

struct SettingsView: View {
    @Environment(\.managedObjectContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.requestReview) private var requestReview
    @Environment(\.openURL) private var openURL
    @AppStorage(Reminders.enabledKey) private var enabled = true
    @AppStorage(Reminders.minutesKey) private var minutes = Reminders.defaultMinutes
    @AppStorage(Reminders.daysKey) private var days = Reminders.defaultDays
    @State private var notificationsDenied = false
    @State private var confirmingDelete = false
    @State private var deleteFailed = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Daily reminder", isOn: $enabled)
                    if enabled {
                        DatePicker("Time", selection: ReminderTime.binding($minutes), displayedComponents: .hourAndMinute)
                        Stepper("Within \(days) days", value: $days, in: 1...14)
                        if notificationsDenied, let settings = AppLinks.systemSettings {
                            Button("Notifications are off for Keepsy. Turn them on in Settings.", systemImage: "bell.slash") {
                                openURL(settings)
                            }
                            .foregroundStyle(Color.soon)
                        }
                    }
                } footer: {
                    Text("One notification a day listing items that expire soon.")
                }

                Section {
                    if let settings = AppLinks.systemSettings {
                        Button("Language and Permissions", systemImage: "gear") { openURL(settings) }
                    }
                    Button("Rate Keepsy", systemImage: "star") { requestReview() }
                    if let support = AppLinks.support {
                        Link(destination: support) {
                            Label("Contact Support", systemImage: "envelope")
                        }
                    }
                    if let privacy = AppLinks.privacyPolicy {
                        Link(destination: privacy) {
                            Label("Privacy Policy", systemImage: "hand.raised")
                        }
                    }
                    LabeledContent("Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "")
                }

                Section {
                    Button("Delete All Data", systemImage: "trash", role: .destructive) { confirmingDelete = true }
                } footer: {
                    // Revisit this wording when iCloud sync is turned on.
                    Text("Your items stay on this iPhone. Nothing is sent to us.")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                Button("Done") { dismiss() }
            }
            .confirmationDialog("Delete all items, places and shopping lists?", isPresented: $confirmingDelete, titleVisibility: .visible) {
                Button("Delete All Data", role: .destructive) {
                    do {
                        try Persistence.deleteAll(in: context)
                    } catch {
                        context.rollback()
                        deleteFailed = true
                    }
                }
            } message: {
                Text("This can't be undone.")
            }
            .alert("Couldn't delete your data. Try again.", isPresented: $deleteFailed) {}
            .task(id: [enabled ? 1 : 0, minutes, days]) {
                await Reminders.reschedule(in: context)
                notificationsDenied = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus == .denied
            }
        }
    }
}

/// Reminder time is stored as minutes after midnight; date pickers want a Date.
enum ReminderTime {
    static func binding(_ minutes: Binding<Int>) -> Binding<Date> {
        Binding {
            Calendar.current.date(bySettingHour: minutes.wrappedValue / 60, minute: minutes.wrappedValue % 60, second: 0, of: .now) ?? .now
        } set: { date in
            let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
            minutes.wrappedValue = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
        }
    }
}

#Preview {
    SettingsView()
        .environment(\.managedObjectContext, Persistence.preview.container.viewContext)
}
