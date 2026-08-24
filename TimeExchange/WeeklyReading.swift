import Foundation
import SwiftData

/// 한 주를 읽은 결과. 다섯 덩어리이고, 서로 더하지 않는다.
///
/// 단위가 다른 숫자를 한 점수로 합치면 그 순간 최적화할 대상이 생기고,
/// 사람은 점수를 올리려고 삶을 바꾼다. 그래서 재무제표처럼 나란히만 둔다.
struct WeeklyReading {

    // MARK: 노랑 — 실현 수익

    struct SoldTag: Identifiable {
        let tag: String
        let cells: Int
        let total: Double
        var id: String { tag }
        var perCell: Double { cells > 0 ? total / Double(cells) : 0 }
    }

    /// 월급 노랑. 금액이 칸에 붙지 않고 그 달의 월급에서 배분된다.
    struct SalaryMonth: Identifiable {
        let key: Int
        let cellsThisWeek: Int
        let cellsInMonth: Int
        let hoursInMonth: Double
        let monthlyPay: Double
        /// 그 달에서 지난 일수. 달 중간이면 월급 전액이 아직 들어온 것이 아니다.
        let elapsedDays: Int
        let daysInMonth: Int

        var id: Int { key }
        var label: String { Week.monthLabel(key) }
        var isPartial: Bool { elapsedDays < daysInMonth }

        /// 지금까지 벌어들인 몫. 달 전체가 지났으면 실수령액 그대로다.
        var pay: Double {
            daysInMonth > 0 ? monthlyPay * Double(elapsedDays) / Double(daysInMonth) : 0
        }
        var perCell: Double { cellsInMonth > 0 ? pay / Double(cellsInMonth) : 0 }
        /// 판 시간 시급. 실제로 노랑으로 칠한 시간으로만 나눈 값이므로 구속 시급보다 높게 나온다.
        var perHour: Double { hoursInMonth > 0 ? pay / hoursInMonth : 0 }
    }

    var soldCells: Int = 0
    var soldPricedCells: Int = 0
    var soldTotal: Double = 0
    var soldTags: [SoldTag] = []
    var salaryCells: Int = 0
    var salaryMonths: [SalaryMonth] = []
    /// 출금 판단에 쓰는 시급. 판 시간 시급과 나란히 두고 절대 섞지 않는다.
    var laborRate: Double = 0
    /// 칸당 실측 단가. 추정 시급이 아니라 실제로 들어온 돈이다.
    var soldPerCell: Double { soldPricedCells > 0 ? soldTotal / Double(soldPricedCells) : 0 }
    /// 단가가 다른 노랑이 섞여 있는가. 여기서 "어느 노랑을 줄일지"가 나온다.
    var soldTagsDiverge: Bool { soldTags.count > 1 }

    // MARK: 파랑 — 심은 시간

    struct SeedTag: Identifiable {
        let tag: String
        /// 전 기간 이 태그의 파란 칸 수. 회수는 이 전체에 소급 배분된다.
        let cellsAllTime: Int
        let cellsThisWeek: Int
        let recovered: Double
        var id: String { tag }
        var perCell: Double { cellsAllTime > 0 ? recovered / Double(cellsAllTime) : 0 }
    }

    var seedCells: Int = 0
    var seedTags: [SeedTag] = []

    // MARK: 빨강 — 배당의 원가

    var joyCells: Int = 0
    /// 누린 시간에 쓴 돈. 이 시간의 가치가 아니라 원가다.
    var joyCost: Double = 0

    // MARK: 초록 — 운영비와 출금

    struct WithdrawalLine: Identifiable {
        let id: PersistentIdentifier
        let dayLabel: String
        let slotLabel: String
        let cost: Double
        let from: TimeColor
        let to: TimeColor
        let netHours: Double
        let ratio: Double
    }

    var careCells: Int = 0
    var careCost: Double = 0
    var withdrawals: [WithdrawalLine] = []

    // MARK: 안개

    var fogCells: Int = 0
    /// 지금까지 지나간 칸 수. 안개는 이 중 아무 색도 없는 칸이다.
    var pastCells: Int = 0

    // MARK: - 계산

    /// 그 달의 전체 일수와, 오늘까지 지난 일수.
    /// 달 중간에 월급 전액을 나누면 아직 벌지 않은 돈까지 배분하게 되므로 경과분만 쓴다.
    static func monthSpan(key: Int, today: Date, calendar: Calendar = .current) -> (elapsed: Int, total: Int) {
        var comps = DateComponents()
        comps.year = key / 100
        comps.month = key % 100
        comps.day = 1
        guard let first = calendar.date(from: comps),
              let range = calendar.range(of: .day, in: .month, for: first) else { return (30, 30) }
        let total = range.count
        let todayKey = Week.monthKey(of: today, calendar: calendar)
        if key < todayKey { return (total, total) }
        if key > todayKey { return (0, total) }
        return (min(calendar.component(.day, from: today), total), total)
    }

    /// 태그 없는 칸도 한 줄로 묶인다. 이름이 없는 것과 기록이 없는 것은 다르다.
    private static func tagKey(_ cell: TimeCell, fallback: String) -> String {
        guard let tag = cell.tag, !tag.isEmpty else { return fallback }
        return tag
    }

    /// - Parameters:
    ///   - days: 월요일부터 일요일까지 7일.
    ///   - throughIndex: 집계에 넣을 마지막 요일 인덱스. 오늘이 속한 주면 오늘, 지난 주면 6, 다음 주면 -1.
    ///   - allCells: 전 기간의 칸. 파랑 회수 배분이 이번 주에 갇히면 안 되므로 전체를 받는다.
    static func compute(days: [Date],
                        throughIndex: Int,
                        allCells: [TimeCell],
                        recoveries: [Recovery],
                        exchanges: [Exchange],
                        monthlyNetPay: Double = 0,
                        laborRate: Double = 0,
                        today: Date = .now,
                        calendar: Calendar = .current) -> WeeklyReading {
        var r = WeeklyReading()
        r.laborRate = laborRate
        guard days.count == 7, throughIndex >= 0 else { return r }

        let countedDays = Set(days.prefix(throughIndex + 1).map { calendar.startOfDay(for: $0) })
        let weekDays = Set(days.map { calendar.startOfDay(for: $0) })
        let past = allCells.filter { countedDays.contains(calendar.startOfDay(for: $0.day)) }

        r.pastCells = countedDays.count * Slot.allCases.count

        // 노랑 — 금액이 붙은 칸만 단가로 읽는다. 전표 없는 노랑은 아직 관측되지 않은 수익이다.
        let sold = past.filter { $0.color == .sold }
        let priced = sold.filter { $0.won != nil && !$0.fromSalary }
        r.soldCells = sold.count
        r.soldPricedCells = priced.count
        r.soldTotal = priced.reduce(0) { $0 + ($1.won ?? 0) }
        var soldByTag: [String: [TimeCell]] = [:]
        for cell in priced { soldByTag[tagKey(cell, fallback: "기타"), default: []].append(cell) }
        var soldLines: [SoldTag] = []
        for (tag, cells) in soldByTag {
            let total: Double = cells.reduce(0) { $0 + ($1.won ?? 0) }
            soldLines.append(SoldTag(tag: tag, cells: cells.count, total: total))
        }
        soldLines.sort { $0.perCell > $1.perCell }
        r.soldTags = soldLines

        // 월급 노랑 — 그 달의 월급을 그 달의 월급 노랑 전체로 나눈다.
        // 출근한 시간을 전부 노랑으로 칠하지 않으면 이 값은 올라간다. 밀도가 올라간 것이지
        // 한 시간을 되사는 값이 싸진 것이 아니므로, 출금 판단에는 여전히 구속 시급을 쓴다.
        let salaryThisWeek = sold.filter(\.fromSalary)
        r.salaryCells = salaryThisWeek.count
        if monthlyNetPay > 0, !salaryThisWeek.isEmpty {
            let salaryAllTime = allCells.filter { $0.color == .sold && $0.fromSalary }
            var cellsInMonth: [Int: Int] = [:]
            var hoursInMonth: [Int: Double] = [:]
            for cell in salaryAllTime {
                let k = Week.monthKey(of: cell.day, calendar: calendar)
                cellsInMonth[k, default: 0] += 1
                hoursInMonth[k, default: 0] += cell.slot.hours
            }
            var weekCountByMonth: [Int: Int] = [:]
            for cell in salaryThisWeek {
                weekCountByMonth[Week.monthKey(of: cell.day, calendar: calendar), default: 0] += 1
            }
            r.salaryMonths = weekCountByMonth.keys.sorted().map { k in
                let span = monthSpan(key: k, today: today, calendar: calendar)
                return SalaryMonth(key: k,
                                   cellsThisWeek: weekCountByMonth[k] ?? 0,
                                   cellsInMonth: cellsInMonth[k] ?? 0,
                                   hoursInMonth: hoursInMonth[k] ?? 0,
                                   monthlyPay: monthlyNetPay,
                                   elapsedDays: span.elapsed,
                                   daysInMonth: span.total)
            }
        }

        // 파랑 — 이번 주 칸 수는 이번 주 것이지만, 회수 배분은 전 기간 칸 수로 나눈다.
        let seedThisWeek = past.filter { $0.color == .seed }
        r.seedCells = seedThisWeek.count
        let seedAllTime = allCells.filter { $0.color == .seed }
        var allTimeCount: [String: Int] = [:]
        for cell in seedAllTime { allTimeCount[tagKey(cell, fallback: "무태그"), default: 0] += 1 }
        var weekCount: [String: Int] = [:]
        for cell in seedThisWeek { weekCount[tagKey(cell, fallback: "무태그"), default: 0] += 1 }
        var recovered: [String: Double] = [:]
        for rec in recoveries where rec.kind == .money { recovered[rec.tag, default: 0] += rec.won }
        let seedTagNames: Set<String> = Set(allTimeCount.keys).union(weekCount.keys)
        var seedLines: [SeedTag] = []
        for tag in seedTagNames {
            let line = SeedTag(tag: tag,
                               cellsAllTime: allTimeCount[tag] ?? 0,
                               cellsThisWeek: weekCount[tag] ?? 0,
                               recovered: recovered[tag] ?? 0)
            if line.cellsThisWeek > 0 || line.recovered > 0 { seedLines.append(line) }
        }
        seedLines.sort { a, b in
            a.recovered == b.recovered ? a.tag < b.tag : a.recovered > b.recovered
        }
        r.seedTags = seedLines

        // 빨강 — 원가만.
        let joy = past.filter { $0.color == .joy }
        r.joyCells = joy.count
        r.joyCost = joy.reduce(0) { $0 + ($1.won ?? 0) }

        // 초록 — 운영비와, 이번 주에 실제로 일어난 출금.
        let care = past.filter { $0.color == .care }
        r.careCells = care.count
        r.careCost = care.reduce(0) { $0 + ($1.won ?? 0) }
        r.withdrawals = exchanges
            .filter { $0.kind == .withdrawal && weekDays.contains(calendar.startOfDay(for: $0.date)) }
            .sorted { $0.date < $1.date }
            .map { ex in
                let index = days.firstIndex { calendar.isDate($0, inSameDayAs: ex.date) } ?? 0
                return WithdrawalLine(id: ex.persistentModelID,
                                      dayLabel: Week.dayLabels[index],
                                      slotLabel: ex.slot?.label ?? "",
                                      cost: ex.won,
                                      from: ex.fromColor ?? .care,
                                      to: ex.toColor ?? .joy,
                                      netHours: ex.netHours,
                                      ratio: ex.ratio)
            }

        // 안개 — 개수만 센다. 돈은 붙이지 않는다.
        r.fogCells = max(0, r.pastCells - past.count)
        return r
    }
}
