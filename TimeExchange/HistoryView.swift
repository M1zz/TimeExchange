import SwiftUI
import SwiftData

struct HistoryView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Exchange.date, order: .reverse) private var all: [Exchange]

    private var days: [DaySummary] {
        let grouped = Dictionary(grouping: all) { Calendar.current.startOfDay(for: $0.date) }
        return grouped.keys.sorted(by: >).map { DaySummary(date: $0, exchanges: grouped[$0] ?? []) }
    }

    var body: some View {
        NavigationStack {
            List {
                if days.isEmpty {
                    ContentUnavailableView("거래 없음", systemImage: "tray", description: Text("오늘 탭에서 입금이나 출금을 기록하세요."))
                }
                ForEach(days, id: \.date) { day in
                    Section {
                        ForEach(day.exchanges) { ex in
                            ExchangeRow(exchange: ex)
                                .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
                                .listRowBackground(Color.clear)
                        }
                        .onDelete { offsets in delete(offsets, in: day) }
                    } header: {
                        HStack {
                            Text(day.date.formatted(.dateTime.month().day().weekday()))
                            Spacer()
                            Text("\(Fmt.hours(day.timeEquivalent)) · 순증 \(Fmt.hours(day.netHours, signed: true))")
                                .monospacedDigit()
                                .foregroundStyle(day.netHours >= 0 ? Color.teal : Color.red)
                        }
                    }
                }
            }
            .navigationTitle("거래내역")
        }
    }

    private func delete(_ offsets: IndexSet, in day: DaySummary) {
        for index in offsets where day.exchanges.indices.contains(index) {
            context.delete(day.exchanges[index])
        }
    }
}
