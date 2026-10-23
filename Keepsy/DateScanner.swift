import AVFoundation
import SwiftUI
import VisionKit

enum PackageDate {
    private static let months = ["JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"]

    /// Finds dates as printed on packages: year first ("2026.10.25", "2026년 10월 25일", "20261025"),
    /// year last ("10/25/2026", "25.10.2026"), month names ("25 OCT 2026", "OCT 25, 2026", "OCT 2026") and two-digit years.
    /// Day/month order and two-digit years follow the region's habit when the numbers alone can't tell.
    /// Packages often also show a production date, so the latest plausible date wins.
    static func parse(_ text: String, now: Date = .now, calendar: Calendar = .current, locale: Locale = .current) -> Date? {
        let region = locale.region?.identifier ?? ""
        let monthFirst = region == "US"
        let yearFirst = ["KR", "JP", "CN", "TW"].contains(region)
        var rest = text.uppercased()
        var found: [(year: Int, month: Int, day: Int)] = []

        // Each pattern consumes what it matched, so a later, looser one can't re-read part of the same date.
        func take<Output>(_ regex: Regex<Output>, _ read: (Output) -> (Int, Int, Int)?) {
            for match in rest.matches(of: regex) {
                if let date = read(match.output) { found.append(date) }
            }
            rest.replace(regex, with: " ")
        }
        func n(_ text: Substring) -> Int { Int(text) ?? 0 }
        func month(_ name: Substring) -> Int { (months.firstIndex(of: String(name.prefix(3))) ?? -1) + 1 }
        func dayMonth(_ a: Int, _ b: Int) -> (Int, Int) {
            if a > 12 { return (b, a) }
            if b > 12 { return (a, b) }
            return monthFirst ? (a, b) : (b, a)
        }

        take(/(20\d{2})\s*[.\-\/년]\s*(\d{1,2})\s*[.\-\/월]\s*(\d{1,2})/) { (n($0.1), n($0.2), n($0.3)) }
        take(/(\d{1,2})\s*[.\-\/]\s*(\d{1,2})\s*[.\-\/]\s*(20\d{2})/) { let (m, d) = dayMonth(n($0.1), n($0.2)); return (n($0.3), m, d) }
        take(/(\d{1,2})\s*(JAN|FEB|MAR|APR|MAY|JUN|JUL|AUG|SEP|OCT|NOV|DEC)[A-Z]*\.?\s*(\d{4}|\d{2})/) { (n($0.3), month($0.2), n($0.1)) }
        take(/(JAN|FEB|MAR|APR|MAY|JUN|JUL|AUG|SEP|OCT|NOV|DEC)[A-Z]*\.?\s*(\d{1,2}),?\s+(20\d{2})/) { (n($0.3), month($0.1), n($0.2)) }
        take(/(JAN|FEB|MAR|APR|MAY|JUN|JUL|AUG|SEP|OCT|NOV|DEC)[A-Z]*\.?\s*(20\d{2})/) { match in
            // Month and year only means "by the end of that month".
            let m = month(match.1), y = n(match.2)
            let last = DateComponents(calendar: calendar, year: y, month: m).date.flatMap { calendar.range(of: .day, in: .month, for: $0)?.count }
            return last.map { (y, m, $0) }
        }
        take(/20(\d{2})(\d{2})(\d{2})/) { (n($0.1), n($0.2), n($0.3)) }
        take(/(\d{2})\s*[.\-\/년]\s*(\d{1,2})\s*[.\-\/월]\s*(\d{1,2})/) { match in
            let (a, b, c) = (n(match.1), n(match.2), n(match.3))
            if yearFirst { return (a, b, c) }
            let (m, d) = dayMonth(a, b)
            return (c, m, d)
        }

        let thisYear = calendar.component(.year, from: now)
        return found
            .compactMap { year, month, day -> Date? in
                let fullYear = year < 100 ? 2000 + year : year
                let parts = DateComponents(calendar: calendar, year: fullYear, month: month, day: day)
                guard parts.isValidDate, (thisYear - 1...thisYear + 10).contains(fullYear) else { return nil }
                return parts.date
            }
            .max()
    }
}

/// Live camera text scanner that reports the first package date it reads.
struct DateScanner: UIViewControllerRepresentable {
    static var isSupported: Bool { DataScannerViewController.isSupported }

    /// Asks for the camera the first time; false means access is off and the user must enable it in Settings.
    static func requestAccess() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: true
        case .notDetermined: await AVCaptureDevice.requestAccess(for: .video)
        default: false
        }
    }

    let onDate: (Date) -> Void

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(recognizedDataTypes: [.text()], qualityLevel: .accurate, isHighlightingEnabled: true)
        scanner.delegate = context.coordinator
        return scanner
    }

    func updateUIViewController(_ scanner: DataScannerViewController, context: Context) {
        if !scanner.isScanning {
            try? scanner.startScanning()
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(onDate: onDate) }

    @MainActor
    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let onDate: (Date) -> Void
        private var found = false

        init(onDate: @escaping (Date) -> Void) {
            self.onDate = onDate
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            let text = allItems.compactMap { item -> String? in
                if case .text(let text) = item { text.transcript } else { nil }
            }.joined(separator: "\n")
            guard !found, let date = PackageDate.parse(text) else { return }
            found = true
            onDate(date)
        }
    }
}

struct DateScannerSheet: View {
    let onDate: (Date) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            DateScanner { date in
                onDate(date)
                dismiss()
            }
            .ignoresSafeArea()
            .overlay(alignment: .bottom) {
                Text("Point the camera at the date on the package")
                    .padding()
                    .background(.regularMaterial, in: .capsule)
                    .padding()
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
