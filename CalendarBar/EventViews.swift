import SwiftUI

struct CurrentEventView: View {
    let event: CalendarEvent?

    var body: some View {
        Group {
            if let event {
                HStack(alignment: .top, spacing: 10) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(event.title)
                            .font(.headline)
                            .lineLimit(1)
                            .truncationMode(.tail)

                    if let location = event.location {
                        Label(location, systemImage: "mappin.and.ellipse")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        }
                    }

                    Spacer(minLength: 8)

                    Text(event.startDate, format: .dateTime.hour().minute())
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(width: 78, alignment: .trailing)
                        .fixedSize()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Label("No event in progress", systemImage: "calendar")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 4)
            }
        }
    }
}

struct UpcomingEventRow: View {
    let event: CalendarEvent

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(Color(hex: event.calendarColorHex))
                .frame(width: 10, height: 10)
                .padding(.top, 5)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(event.title)
                    .lineLimit(1)
                    .truncationMode(.tail)

                if let location = event.location {
                    Label(location, systemImage: "mappin.and.ellipse")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            Text(event.startDate, format: .dateTime.hour().minute())
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 78, alignment: .trailing)
                .fixedSize()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(event.title), starts \(event.startDate.formatted(date: .omitted, time: .shortened))"
                + (event.location.map { ", at \($0)" } ?? "")
        )
        .padding(.vertical, 7)
        .contentShape(Rectangle())
    }
}

private extension Color {
    init(hex: String) {
        let value = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        let number = UInt64(value, radix: 16) ?? 0x5E5CE6

        self.init(
            red: Double((number >> 16) & 0xFF) / 255,
            green: Double((number >> 8) & 0xFF) / 255,
            blue: Double(number & 0xFF) / 255
        )
    }
}
