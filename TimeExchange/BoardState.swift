import Foundation
import Observation

/// 색칠판과 주간 읽기가 같은 주를 보도록 잡아 두는 상태.
/// 한 화면에서 주를 넘기면 다른 화면도 같이 넘어가야 두 화면이 한 장부로 읽힌다.
@Observable
final class BoardState {
    var monday: Date = Week.monday(of: .now)

    func weekTitle(calendar: Calendar = .current) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "M월 d일"
        let end = calendar.date(byAdding: .day, value: 6, to: monday) ?? monday
        let suffix = calendar.isDate(monday, inSameDayAs: Week.monday(of: .now, calendar: calendar)) ? " · 이번 주" : ""
        return f.string(from: monday) + " – " + f.string(from: end) + suffix
    }
}
