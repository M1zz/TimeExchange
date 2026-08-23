import Foundation
import SwiftData

/// 환전 방향. deposit = 시간을 팔아 돈으로 저축, withdrawal = 돈을 꺼내 시간을 삼.
enum ExchangeKind: String, Codable, CaseIterable {
    case deposit, withdrawal

    var label: String { self == .deposit ? "입금" : "출금" }
    var subtitle: String { self == .deposit ? "시간 → 돈" : "돈 → 시간" }
    var symbol: String { self == .deposit ? "arrow.down.to.line" : "arrow.up.from.line" }
}

extension ExchangeKind: Identifiable {
    var id: String { rawValue }
}

@Model
final class Exchange {
    var kindRaw: String
    var date: Date
    var title: String
    /// 금액 (원)
    var won: Double
    /// deposit: 일한 시간, withdrawal: 돌려받은 시간
    var hours: Double
    /// 거래 당시 내 시급. 환율은 시점마다 다르므로 기록해 둔다.
    var myRateAtTime: Double

    init(kind: ExchangeKind, date: Date = .now, title: String, won: Double, hours: Double, myRateAtTime: Double) {
        self.kindRaw = kind.rawValue
        self.date = date
        self.title = title
        self.won = won
        self.hours = hours
        self.myRateAtTime = myRateAtTime
    }

    var kind: ExchangeKind { ExchangeKind(rawValue: kindRaw) ?? .deposit }

    /// 이 거래의 환율. deposit이면 번 시급, withdrawal이면 산 시급.
    var rate: Double { hours > 0 ? won / hours : 0 }

    /// withdrawal 전용. 번 시급 ÷ 산 시급. 1보다 커야 시간이 실제로 늘어난다.
    var ratio: Double {
        guard kind == .withdrawal, rate > 0 else { return 0 }
        return myRateAtTime / rate
    }

    /// withdrawal 전용. 돌려받은 시간 − 그 돈을 벌려고 쓴 시간.
    var netHours: Double {
        guard kind == .withdrawal, myRateAtTime > 0 else { return 0 }
        return hours - won / myRateAtTime
    }
}

/// 환율 입력값의 기본치. UserDefaults 키는 각 뷰의 @AppStorage 이름과 같다.
enum RateDefaults {
    static let monthlyNetPay = 3_500_000.0
    static let weeklyWorkHours = 40.0
    static let workDaysPerMonth = 22.0
    static let dailyCommuteHours = 1.5
    static let totalAssets = 0.0
    static let annualReturnPercent = 4.0
}

/// 월급·근무시간·자산에서 두 종류의 환율을 도출한다.
/// 노동 환율은 시간을 내줘야 나오고, 자산 환율은 안 내줘도 나온다. 성격이 달라 합치지 않는다.
struct RateProfile {
    var monthlyNetPay: Double
    var weeklyWorkHours: Double
    var workDaysPerMonth: Double
    var dailyCommuteHours: Double
    var totalAssets: Double
    var annualReturnPercent: Double

    /// 주 단위 근무를 월로 환산하는 계수 (52주 ÷ 12개월).
    static let weeksPerMonth = 52.0 / 12.0
    /// 1년의 시간. 자산은 자는 동안에도 일하므로 근무시간이 아니라 달력 시간으로 나눈다.
    static let hoursPerYear = 365.0 * 24.0

    var monthlyWorkHours: Double { weeklyWorkHours * Self.weeksPerMonth }
    var monthlyCommuteHours: Double { dailyCommuteHours * workDaysPerMonth }

    /// 급여를 받기 위해 회사에 매인 전체 시간. 통근도 판 시간이므로 분모에 넣는다.
    var monthlyCommittedHours: Double { monthlyWorkHours + monthlyCommuteHours }

    /// 노동 환율. 시간을 팔 때 실제로 손에 쥐는 시급이며 앱의 핵심 환율이다.
    var laborRate: Double {
        monthlyCommittedHours > 0 ? monthlyNetPay / monthlyCommittedHours : 0
    }

    /// 자산 환율. 돈이 나 대신 버는 시급.
    var assetRate: Double {
        totalAssets * (annualReturnPercent / 100) / Self.hoursPerYear
    }

    /// 통근을 빼고 계산했을 때의 시급. 실제보다 얼마나 부풀려지는지 보여주는 참고값.
    var rateIgnoringCommute: Double {
        monthlyWorkHours > 0 ? monthlyNetPay / monthlyWorkHours : 0
    }

    /// 통근을 무시하면 시급이 몇 % 부풀려지는지.
    var commuteInflationPercent: Double {
        guard laborRate > 0 else { return 0 }
        return (rateIgnoringCommute - laborRate) / laborRate * 100
    }
}

/// 하루치 집계.
struct DaySummary {
    let date: Date
    let exchanges: [Exchange]

    var deposits: [Exchange] { exchanges.filter { $0.kind == .deposit } }
    var withdrawals: [Exchange] { exchanges.filter { $0.kind == .withdrawal } }

    var depositedWon: Double { deposits.reduce(0) { $0 + $1.won } }
    var soldHours: Double { deposits.reduce(0) { $0 + $1.hours } }
    var withdrawnWon: Double { withdrawals.reduce(0) { $0 + $1.won } }
    var boughtHours: Double { withdrawals.reduce(0) { $0 + $1.hours } }
    var netHours: Double { withdrawals.reduce(0) { $0 + $1.netHours } }

    /// 24 + 돈으로 산 시간
    var timeEquivalent: Double { 24 + boughtHours }
    var density: Double { timeEquivalent / 24 }
    /// 평생 관점 하루 길이
    var lifetimeHours: Double { 24 + netHours }
}

enum Fmt {
    static func won(_ v: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 0
        return (f.string(from: NSNumber(value: v)) ?? "0") + "원"
    }
    static func hours(_ v: Double, signed: Bool = false) -> String {
        let s = String(format: "%.1f", abs(v))
        if signed { return (v >= 0 ? "+" : "−") + s + "h" }
        return (v < 0 ? "−" : "") + s + "h"
    }
    static func ratio(_ v: Double) -> String { String(format: "%.2f", v) }
    static func percent(_ v: Double) -> String { String(format: "%.0f%%", v) }
}
