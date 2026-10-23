import PhotosUI
import SwiftUI

struct BatchEditor: View {
    private let batch: Batch?
    private let isRestock: Bool

    @Environment(\.managedObjectContext) private var context
    @Environment(\.dismiss) private var dismiss
    @FetchRequest(sortDescriptors: [SortDescriptor(\Location.sortOrder), SortDescriptor(\Location.name)])
    private var locations: FetchedResults<Location>
    @FetchRequest(sortDescriptors: [SortDescriptor(\Item.name)], predicate: NSPredicate(value: false))
    private var previousItems: FetchedResults<Item>
    @State private var draft: BatchDraft
    @State private var pickedPhoto: PhotosPickerItem?
    @State private var showSaveError = false
    @State private var scanningDate = false

    init(target: EditorTarget) {
        switch target {
        case .new(let location):
            batch = nil
            isRestock = false
            _draft = State(initialValue: BatchDraft(location: location))
        case .edit(let batch):
            self.batch = batch
            isRestock = false
            _draft = State(initialValue: BatchDraft(batch: batch))
        case .restock(let item):
            batch = nil
            isRestock = true
            var draft = BatchDraft()
            draft.fill(from: item)
            _draft = State(initialValue: draft)
        }
    }

    var body: some View {
        let photo = draft.photo
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 14) {
                        PhotosPicker(selection: $pickedPhoto, matching: .images) {
                            PhotoThumbnail(data: photo)
                        }
                        .buttonStyle(.plain)
                        TextField("Name", text: $draft.name)
                            .font(.title3.weight(.semibold))
                    }
                    Picker("Location", selection: $draft.location) {
                        Text("None").tag(Location?.none)
                        ForEach(locations.sorted { $0.treeOrder.lexicographicallyPrecedes($1.treeOrder) }) { location in
                            Text(location.path).tag(Optional(location))
                        }
                    }
                }
                if batch == nil && !isRestock && !previousItems.isEmpty {
                    Section("Previously added") {
                        ForEach(previousItems.prefix(5)) { item in
                            Button(item.name ?? "", systemImage: "arrow.uturn.backward") { draft.fill(from: item) }
                        }
                    }
                }
                expirySection
                Section {
                    Stepper("Quantity: \(draft.quantity)", value: $draft.quantity, in: 1...99)
                    LevelPicker(selection: $draft.level)
                } header: {
                    Text("Amount")
                }
                if let data = draft.photo, let image = UIImage(data: data) {
                    Section("Photo") {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 240)
                            .frame(maxWidth: .infinity)
                            .accessibilityLabel(Text("Photo"))
                        Button("Remove Photo", role: .destructive) {
                            draft.photo = nil
                            pickedPhoto = nil
                        }
                    }
                }
                if let batch {
                    Section {
                        Button("Delete", role: .destructive) {
                            context.delete(batch)
                            try? context.save()
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle(isRestock ? "Bought Again" : batch == nil ? "Add Item" : "Edit Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(!draft.isValid)
                }
            }
            .onChange(of: draft.name) {
                let name = draft.name.trimmingCharacters(in: .whitespaces)
                previousItems.nsPredicate = name.isEmpty
                    ? NSPredicate(value: false)
                    : NSPredicate(format: "name CONTAINS[cd] %@ AND NOT (name ==[c] %@)", name, name)
            }
            .task(id: pickedPhoto) {
                guard let data = try? await pickedPhoto?.loadTransferable(type: Data.self) else { return }
                draft.photo = data.downscaledJPEG()
            }
            .alert("Couldn't save", isPresented: $showSaveError) {}
            .fullScreenCover(isPresented: $scanningDate) {
                DateScannerSheet { draft.expiresAt = $0 }
            }
        }
    }

    private var expirySection: some View {
        Section {
            Toggle("Expires", isOn: $draft.hasExpiry.animation())
            if draft.hasExpiry {
                HStack {
                    DatePicker("Expiration date", selection: $draft.expiresAt, displayedComponents: .date)
                        .labelsHidden()
                    Spacer()
                    let days = Expiry.daysLeft(until: draft.expiresAt)
                    Text(Expiry.label(daysLeft: days))
                        .font(.stamp(.title3))
                        .foregroundStyle(Expiry.color(daysLeft: days))
                        .contentTransition(.numericText())
                }
                QuickDates(selection: $draft.expiresAt)
                if DateScanner.isAvailable {
                    Button("Scan Date", systemImage: "camera.viewfinder") { scanningDate = true }
                }
            }
        } header: {
            Text("Expiration")
        } footer: {
            if isRestock {
                Text("Filled in from last time. Check the date on the new package.")
            }
        }
    }

    private func save() {
        do {
            try draft.save(to: batch, in: context)
            dismiss()
        } catch {
            context.rollback()
            showSaveError = true
        }
    }
}

private struct PhotoThumbnail: View {
    let data: Data?
    @ScaledMetric private var side = 64.0

    var body: some View {
        Group {
            if let data, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "camera")
                    .font(.title3)
                    .foregroundStyle(Color.accentColor)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.accentColor.opacity(0.12))
            }
        }
        .frame(width: side, height: side)
        .clipShape(.rect(cornerRadius: 14))
        .accessibilityLabel(Text("Choose Photo"))
    }
}

/// One-tap shelf lives counted from today.
private struct QuickDates: View {
    @Binding var selection: Date

    private static let options: [(LocalizedStringResource, Calendar.Component, Int)] = [
        ("3 days", .day, 3), ("1 week", .day, 7), ("2 weeks", .day, 14), ("1 month", .month, 1), ("6 months", .month, 6),
    ]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Self.options.indices, id: \.self) { index in
                    let (title, unit, value) = Self.options[index]
                    Button {
                        withAnimation {
                            selection = Calendar.current.date(byAdding: unit, value: value, to: .now) ?? selection
                        }
                    } label: {
                        Text(title)
                            .font(.subheadline.weight(.medium))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color(.secondarySystemFill), in: .capsule)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

/// Four gauge buttons instead of a segmented control, so the amount reads at a glance.
private struct LevelPicker: View {
    @Binding var selection: Level

    var body: some View {
        HStack(spacing: 8) {
            ForEach(Level.allCases.reversed()) { level in
                let isOn = selection == level
                Button {
                    selection = level
                } label: {
                    VStack(spacing: 6) {
                        LevelGauge(level: level)
                        Text(level.title)
                            .font(.caption.weight(.medium))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(isOn ? Color.accentColor.opacity(0.15) : Color(.secondarySystemFill), in: .rect(cornerRadius: 12))
                    .overlay {
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(isOn ? Color.accentColor : .clear, lineWidth: 2)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isOn ? .isSelected : [])
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview("Add") {
    BatchEditor(target: .new(nil))
        .environment(\.managedObjectContext, Persistence.preview.container.viewContext)
}
