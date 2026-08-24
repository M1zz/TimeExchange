import Foundation

/// 자산 한 개의 장부. 파랑 태그 하나에 해당한다.
///
/// 돈·시간·배당은 단위가 달라 더하지 않는다. 여기서도 나란히만 둔다.
/// 다만 "아직 아무것도 돌아오지 않았다"는 상태만은 분명히 말한다. 그게 이 장부의 목적이다.
struct AssetLedger: Identifiable {
    let tag: String
    /// 심은 시간.
    let cells: Int
    let hours: Double
    let firstPlanted: Date?
    let lastPlanted: Date?

    /// 돌아온 것들.
    let money: Double
    let timeBack: Double
    /// 이 자산에서 나왔다고 표시된 빨강 칸. 값을 매기지 않고 개수만 센다.
    let dividendCells: Int
    let dividendHours: Double

    let closed: Bool
    let closedAt: Date?

    var id: String { tag }

    var hasReturn: Bool { money > 0 || timeBack > 0 || dividendCells > 0 }

    /// 회수된 돈을 심은 시간으로 나눈 값. 회수가 없으면 계산하지 않는다.
    /// 회수 전에 이 값을 만들면 항상 0원이 되고, 그 0원이 파랑을 죽인다.
    var moneyPerHour: Double? {
        guard money > 0, hours > 0 else { return nil }
        return money / hours
    }

    var moneyPerCell: Double? {
        guard money > 0, cells > 0 else { return nil }
        return money / Double(cells)
    }

    func weeks(since date: Date?, until today: Date, calendar: Calendar = .current) -> Int? {
        guard let date else { return nil }
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: date),
                                           to: calendar.startOfDay(for: today)).day ?? 0
        return max(0, days / 7)
    }

    /// 심은 지 몇 주.
    func age(today: Date, calendar: Calendar = .current) -> Int? {
        weeks(since: firstPlanted, until: today, calendar: calendar)
    }

    /// 마지막으로 심은 지 몇 주. 오래되면 방치된 자산이다.
    func idle(today: Date, calendar: Calendar = .current) -> Int? {
        weeks(since: lastPlanted, until: today, calendar: calendar)
    }

    // MARK: - 만들기

    static func build(cells allCells: [TimeCell],
                      recoveries: [Recovery],
                      calendar: Calendar = .current) -> [AssetLedger] {
        let seeds = allCells.filter { $0.color == .seed && $0.tag?.isEmpty == false }
        let dividends = allCells.filter { $0.color == .joy && $0.tag?.isEmpty == false }

        var names = Set(seeds.compactMap(\.tag))
        names.formUnion(recoveries.map(\.tag))
        names.formUnion(dividends.compactMap(\.tag))

        return names.map { tag in
            let mine = seeds.filter { $0.tag == tag }
            let paid = recoveries.filter { $0.tag == tag }
            let joy = dividends.filter { $0.tag == tag }
            let closing = paid.first { $0.kind == .closed }

            return AssetLedger(
                tag: tag,
                cells: mine.count,
                hours: mine.reduce(0) { $0 + $1.slot.hours },
                firstPlanted: mine.map(\.day).min(),
                lastPlanted: mine.map(\.day).max(),
                money: paid.filter { $0.kind == .money }.reduce(0) { $0 + $1.won },
                timeBack: paid.filter { $0.kind == .time }.reduce(0) { $0 + $1.hours },
                dividendCells: joy.count,
                dividendHours: joy.reduce(0) { $0 + $1.slot.hours },
                closed: closing != nil,
                closedAt: closing?.date
            )
        }
        .sorted { a, b in
            // 접은 것은 아래로. 나머지는 심은 시간이 많은 순.
            if a.closed != b.closed { return !a.closed }
            if a.hours != b.hours { return a.hours > b.hours }
            return a.tag < b.tag
        }
    }
}
