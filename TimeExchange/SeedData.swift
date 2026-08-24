import Foundation
import SwiftData

/// 첫 실행에 데모 한 주를 깔아 둔다.
/// 빈 격자에서는 "합산하지 않는다"는 원칙이 보이지 않는다. 단가가 갈리는 노랑 세 개와
/// 회수 전 파랑, 회수된 파랑이 나란히 있어야 이 장부가 무엇을 말하는지 한 화면에 드러난다.
enum SeedData {

    /// 요일별 여덟 칸. nil은 안개.
    private struct Paint {
        let color: TimeColor?
        let won: Double?
        let tag: String?
        let salary: Bool
        init(_ color: TimeColor? = nil, _ won: Double? = nil, _ tag: String? = nil, salary: Bool = false) {
            self.color = color; self.won = won; self.tag = tag; self.salary = salary
        }
        /// 출근해서 판 시간. 금액이 칸에 붙지 않고 그 달의 월급에서 배분된다.
        static let wage = Paint(.sold, nil, nil, salary: true)
    }

    private static let week: [[Paint]] = [
        // 월
        [Paint(.care), Paint(.care), Paint(.sold, 120_000, "멘토링"), Paint(.sold, 120_000, "멘토링"),
         Paint.wage, Paint.wage, Paint(.joy, 30_000), Paint(.seed, nil, "환전소 앱")],
        // 화
        [Paint(.care), Paint(.seed, nil, "devkoan 글"), Paint(.sold, 200_000, "외주"), Paint(.sold, 200_000, "외주"),
         Paint(.sold, 200_000, "외주"), Paint(), Paint(), Paint(.care, 15_000)],
        // 수
        [Paint(.care), Paint(.care), Paint(.sold, 90_000, "강의"), Paint(.sold, 90_000, "강의"),
         Paint.wage, Paint.wage, Paint(.joy, nil, "devkoan 글"), Paint(.joy, 42_000)],
        // 목
        [Paint(.care), Paint(.seed, nil, "환전소 앱"), Paint.wage, Paint(),
         Paint(.sold, 90_000, "강의"), Paint.wage, Paint(), Paint()],
        // 금
        [Paint(.care, 30_000), Paint(.seed, nil, "환전소 앱"), Paint.wage, Paint.wage,
         Paint(), Paint(), Paint(), Paint()],
        [], []
    ]

    /// - Returns: 처음 열어야 할 주의 월요일. 이번 주가 아직 얕으면 데모가 다 보이는 지난 주를 가리킨다.
    @discardableResult
    static func install(into context: ModelContext, calendar: Calendar = .current) -> Date? {
        let today = calendar.startOfDay(for: .now)
        let thisMonday = Week.monday(of: today, calendar: calendar)
        let todayIndex = calendar.dateComponents([.day], from: thisMonday, to: today).day ?? 0

        // 이번 주는 오늘까지만 칠한다. 아직 오지 않은 칸에 기록이 있으면 그건 장부가 아니라 계획이다.
        paint(week: thisMonday, throughIndex: todayIndex, into: context, calendar: calendar)

        // 주 초반이면 이번 주만으로는 읽을 게 없다. 지난 주에 데모를 통째로 깔고 거기서 시작한다.
        var focus: Date?
        if todayIndex < 4, let lastMonday = calendar.date(byAdding: .day, value: -7, to: thisMonday) {
            paint(week: lastMonday, throughIndex: 6, into: context, calendar: calendar)
            focus = lastMonday
        }

        context.insert(Recovery(tag: "devkoan 글", kind: .money, won: 180_000, date: today))
        return focus
    }

    private static func paint(week monday: Date, throughIndex: Int, into context: ModelContext, calendar: Calendar) {
        for (dayIndex, column) in week.enumerated() where dayIndex <= throughIndex {
            guard let day = calendar.date(byAdding: .day, value: dayIndex, to: monday) else { continue }
            for (slotIndex, paint) in column.enumerated() {
                guard let color = paint.color, let slot = Slot(rawValue: slotIndex) else { continue }
                context.insert(TimeCell(day: calendar.startOfDay(for: day),
                                        slot: slot,
                                        color: color,
                                        won: paint.won,
                                        tag: paint.tag,
                                        fromSalary: paint.salary))
            }
        }
    }
}
