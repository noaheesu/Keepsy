import SwiftUI

struct SettingsView: View {
    @Environment(\.managedObjectContext) private var context
    @Environment(\.dismiss) private var dismiss
    @AppStorage(Reminders.enabledKey) private var enabled = true
    @AppStorage(Reminders.minutesKey) private var minutes = Reminders.defaultMinutes
    @AppStorage(Reminders.daysKey) private var days = Reminders.defaultDays

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Daily reminder", isOn: $enabled)
                    if enabled {
                        DatePicker("Time", selection: time, displayedComponents: .hourAndMinute)
                        Stepper("Within \(days) days", value: $days, in: 1...14)
                    }
                } footer: {
                    Text("One notification a day listing items that expire soon.")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                Button("Done") { dismiss() }
            }
            .task(id: [enabled ? 1 : 0, minutes, days]) {
                await Reminders.reschedule(in: context)
            }
        }
    }

    private var time: Binding<Date> {
        Binding {
            Calendar.current.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: .now) ?? .now
        } set: { date in
            let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
            minutes = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
        }
    }
}

#Preview {
    SettingsView()
        .environment(\.managedObjectContext, Persistence.preview.container.viewContext)
}
