import Foundation
import SwiftData
import SwiftUI

// MARK: - 시간의 색

/// 시간의 계정과목. 색마다 돈이 붙는 방식이 다르고, 그 다름이 이 앱의 회계 원칙이다.
/// 안개는 여기 없다. 안개는 색이 아니라 색의 부재이므로 `nil`로 표현한다.
enum TimeColor: String, Codable, CaseIterable, Identifiable {
    case sold, seed, joy, care

    var id: String { rawValue }

    var label: String {
        switch self {
        case .sold: "팔았다"
        case .seed: "심었다"
        case .joy:  "누렸다"
        case .care: "돌봤다"
        }
    }

    /// 이 색이 장부에서 무엇으로 잡히는가.
    var account: String {
        switch self {
        case .sold: "실현 수익"
        case .seed: "자산에 심은 시간"
        case .joy:  "배당의 원가"
        case .care: "운영비 / 출금"
        }
    }

    var tint: Color {
        switch self {
        case .sold: Palette.sold
        case .seed: Palette.seed
        case .joy:  Palette.joy
        case .care: Palette.care
        }
    }

    /// 이 색의 칸에 금액을 붙일 수 있는가. 파랑만 붙일 수 없다.
    var takesAmount: Bool { self != .seed }
    /// 이 색의 칸에 태그를 붙일 수 있는가.
    ///
    /// 빨강의 태그는 성격이 다르다. 무엇을 팔았나(노랑) / 어디에 심었나(파랑)가 아니라,
    /// **어느 자산이 이 시간을 만들어 줬나**를 가리킨다. 배당의 출처다.
    var takesTag: Bool { self != .care }
}

/// 하루를 여덟 칸으로 쪼갠다. 칸마다 길이가 다른 이유는 사람의 하루가 균등하지 않기 때문이다.
/// 이 길이는 초록 칸을 돈으로 살 때 "몇 시간을 되샀는가"의 기본값이 된다.
enum Slot: Int, Codable, CaseIterable, Identifiable {
    case dawn, morning, forenoon, lunch, afternoon, lateAfternoon, evening, night

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .dawn:          "새벽"
        case .morning:       "아침"
        case .forenoon:      "오전"
        case .lunch:         "점심"
        case .afternoon:     "오후"
        case .lateAfternoon: "늦오후"
        case .evening:       "저녁"
        case .night:         "밤"
        }
    }

    var clock: String {
        switch self {
        case .dawn:          "05–07"
        case .morning:       "07–09"
        case .forenoon:      "09–12"
        case .lunch:         "12–14"
        case .afternoon:     "14–17"
        case .lateAfternoon: "17–19"
        case .evening:       "19–22"
        case .night:         "22–05"
        }
    }

    /// 칸의 길이(시간). 여덟 칸을 더하면 24가 된다.
    var hours: Double {
        switch self {
        case .dawn, .morning, .lunch, .lateAfternoon: 2
        case .forenoon, .afternoon, .evening:         3
        case .night:                                  7
        }
    }
}

// MARK: - 칸

/// 칠해진 칸 하나. 안개 칸은 저장하지 않는다. 기록이 없는 것이 곧 안개다.
@Model
final class TimeCell {
    /// 그 날의 자정. 요일 그리드의 세로줄.
    var day: Date
    var slotRaw: Int
    var colorRaw: String
    /// 붙은 금액. 파랑은 항상 nil이다.
    var won: Double?
    /// 무엇을 팔았나 / 어느 자산에 심었나.
    var tag: String?
    /// 월급에서 나오는 노랑인가.
    ///
    /// 월급은 칸마다 입금되지 않는다. 출근한 시간 전체에 뭉텅이로 들어온다.
    /// 그래서 이 칸에는 금액을 붙이지 않고, 그 달의 월급을 이런 칸들로 나눈다.
    /// 파랑의 회수와 같은 구조다.
    var fromSalary: Bool = false

    init(day: Date, slot: Slot, color: TimeColor, won: Double? = nil, tag: String? = nil, fromSalary: Bool = false) {
        self.day = day
        self.slotRaw = slot.rawValue
        self.colorRaw = color.rawValue
        self.won = won
        self.tag = tag
        self.fromSalary = fromSalary
    }

    var slot: Slot { Slot(rawValue: slotRaw) ?? .dawn }
    var color: TimeColor { TimeColor(rawValue: colorRaw) ?? .care }

    /// 전표가 붙어 있는가. 색을 바꾸면 사라지는 것이 이것이다.
    var hasLedger: Bool { won != nil || (tag?.isEmpty == false) || fromSalary }

    /// 색을 바꾼다. 계정과목이 바뀌면 전표 이월은 회계상 틀리므로 함께 비운다.
    func repaint(to color: TimeColor) {
        self.colorRaw = color.rawValue
        self.won = nil
        self.tag = nil
        self.fromSalary = false
    }
}

// MARK: - 회수

/// 심은 시간이 무엇으로 돌아왔는가.
///
/// 시간을 넣으면 돌아오는 형태는 하나가 아니다. 돈이 들어오기도 하고, 도구를 만들어서
/// 앞으로 쓸 시간이 줄기도 한다. 그리고 아무것도 돌아오지 않은 채 끝나기도 한다.
/// 그 세 번째를 적을 자리가 없으면 장부는 성공한 것만 기억한다.
enum RecoveryKind: String, Codable, CaseIterable, Identifiable {
    case money, time, closed

    var id: String { rawValue }

    var label: String {
        switch self {
        case .money:  "돈"
        case .time:   "시간"
        case .closed: "접음"
        }
    }

    var detail: String {
        switch self {
        case .money:  "이 자산에서 돈이 들어왔다"
        case .time:   "이 자산 덕분에 앞으로 쓸 시간이 줄었다"
        case .closed: "회수 없이 끝냈다"
        }
    }
}

/// 파랑의 회수. 심은 시간은 매일 평가하지 않고, 실현된 날에만 그 태그로 들어온다.
@Model
final class Recovery {
    var tag: String
    var kindRaw: String = RecoveryKind.money.rawValue
    /// money일 때의 금액.
    var won: Double
    /// time일 때 돌아온 시간.
    var hours: Double = 0
    var date: Date
    var note: String?

    init(tag: String,
         kind: RecoveryKind = .money,
         won: Double = 0,
         hours: Double = 0,
         date: Date = .now,
         note: String? = nil) {
        self.tag = tag
        self.kindRaw = kind.rawValue
        self.won = won
        self.hours = hours
        self.date = date
        self.note = note
    }

    var kind: RecoveryKind { RecoveryKind(rawValue: kindRaw) ?? .money }

    /// 한 줄로 읽었을 때의 표기.
    var summary: String {
        switch kind {
        case .money:  Fmt.won(won)
        case .time:   Fmt.hours(hours)
        case .closed: "접음"
        }
    }
}

// MARK: - 환전 (출금)

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

    /// 색칠판과의 연결 고리. 어느 칸을 샀고, 비워진 칸에 무엇이 들어왔는가.
    var slotRaw: Int?
    var fromColorRaw: String?
    var toColorRaw: String?

    init(kind: ExchangeKind,
         date: Date = .now,
         title: String,
         won: Double,
         hours: Double,
         myRateAtTime: Double,
         slot: Slot? = nil,
         fromColor: TimeColor? = nil,
         toColor: TimeColor? = nil) {
        self.kindRaw = kind.rawValue
        self.date = date
        self.title = title
        self.won = won
        self.hours = hours
        self.myRateAtTime = myRateAtTime
        self.slotRaw = slot?.rawValue
        self.fromColorRaw = fromColor?.rawValue
        self.toColorRaw = toColor?.rawValue
    }

    var kind: ExchangeKind { ExchangeKind(rawValue: kindRaw) ?? .deposit }
    var slot: Slot? { slotRaw.flatMap(Slot.init(rawValue:)) }
    var fromColor: TimeColor? { fromColorRaw.flatMap(TimeColor.init(rawValue:)) }
    var toColor: TimeColor? { toColorRaw.flatMap(TimeColor.init(rawValue:)) }

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

// MARK: - 환율

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

// MARK: - 주 계산

enum Week {
    static let dayLabels = ["월", "화", "수", "목", "금", "토", "일"]

    /// 그 날이 속한 주의 월요일 자정. ko_KR 캘린더가 일요일 시작이어도 그리드는 월요일에서 시작한다.
    static func monday(of date: Date, calendar: Calendar = .current) -> Date {
        let start = calendar.startOfDay(for: date)
        let weekday = calendar.component(.weekday, from: start) // 1 = 일요일
        let delta = (weekday + 5) % 7                           // 월 = 0 … 일 = 6
        return calendar.date(byAdding: .day, value: -delta, to: start) ?? start
    }

    static func days(from monday: Date, calendar: Calendar = .current) -> [Date] {
        (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: monday) }
    }

    /// 월급은 달 단위로 들어오므로 배분도 달 단위로 묶는다.
    static func monthKey(of date: Date, calendar: Calendar = .current) -> Int {
        let c = calendar.dateComponents([.year, .month], from: date)
        return (c.year ?? 0) * 100 + (c.month ?? 0)
    }

    static func monthLabel(_ key: Int) -> String { "\(key % 100)월" }
}

// MARK: - 표기

enum Fmt {
    private static let decimal: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 0
        return f
    }()

    static func won(_ v: Double) -> String {
        (decimal.string(from: NSNumber(value: v.rounded())) ?? "0") + "원"
    }
    static func hours(_ v: Double, signed: Bool = false) -> String {
        let s = String(format: "%.1f", abs(v))
        if signed { return (v >= 0 ? "+" : "−") + s + "h" }
        return (v < 0 ? "−" : "") + s + "h"
    }
    static func ratio(_ v: Double) -> String { String(format: "%.2f", v) }
    static func percent(_ v: Double) -> String { String(format: "%.0f%%", v) }

    private static let digits = ["", "일", "이", "삼", "사", "오", "육", "칠", "팔", "구"]
    private static let small = ["", "십", "백", "천"]
    private static let big = ["", "만", "억", "조", "경"]

    /// 금액을 한글로 읽는다. 1000000 → 백만. 45000 → 사만 오천.
    /// 0이 몇 개인지 세다가 한 자리 틀리는 일을 막는 것이 목적이므로, 입력한 그대로를 소리내어 읽는다.
    static func korean(_ amount: Double) -> String {
        let n = Int(amount.rounded())
        if n == 0 { return "영" }
        if n < 0 { return "마이너스 " + korean(Double(-n)) }

        var groups: [Int] = []
        var rest = n
        while rest > 0 {
            groups.append(rest % 10_000)
            rest /= 10_000
        }
        guard groups.count <= big.count else { return "" }

        var parts: [String] = []
        for index in stride(from: groups.count - 1, through: 0, by: -1) {
            let g = groups[index]
            if g == 0 { continue }
            // 만 단위의 1은 읽지 않는다. 일만원이 아니라 만원이다.
            let body = (index == 1 && g == 1) ? "" : fourDigits(g)
            parts.append(body + big[index])
        }
        return parts.joined(separator: " ")
    }

    /// 네 자리 이하를 읽는다. 천·백·십 앞의 1은 읽지 않는다. 1200 → 천이백.
    private static func fourDigits(_ value: Int) -> String {
        var s = ""
        var place = 1000
        var position = 3
        while place >= 1 {
            let d = (value / place) % 10
            if d != 0 {
                s += (position > 0 && d == 1) ? small[position] : digits[d] + small[position]
            }
            place /= 10
            position -= 1
        }
        return s
    }
}
