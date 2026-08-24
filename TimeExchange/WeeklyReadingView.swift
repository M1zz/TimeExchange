import SwiftUI
import SwiftData

/// 주간 읽기. 다섯 줄이고 총점이 없다.
struct WeeklyReadingView: View {
    @Environment(\.modelContext) private var context
    @Environment(BoardState.self) private var board

    @Query(sort: \TimeCell.day) private var allCells: [TimeCell]
    @Query(sort: \Recovery.date, order: .reverse) private var recoveries: [Recovery]
    @Query private var exchanges: [Exchange]

    @AppStorage("monthlyNetPay") private var monthlyNetPay = RateDefaults.monthlyNetPay
    @AppStorage("weeklyWorkHours") private var weeklyWorkHours = RateDefaults.weeklyWorkHours
    @AppStorage("workDaysPerMonth") private var workDaysPerMonth = RateDefaults.workDaysPerMonth
    @AppStorage("dailyCommuteHours") private var dailyCommuteHours = RateDefaults.dailyCommuteHours
    @AppStorage("totalAssets") private var totalAssets = RateDefaults.totalAssets
    @AppStorage("annualReturnPercent") private var annualReturnPercent = RateDefaults.annualReturnPercent

    private let calendar = Calendar.current

    private var days: [Date] { Week.days(from: board.monday, calendar: calendar) }

    private var throughIndex: Int {
        let today = calendar.startOfDay(for: .now)
        if let i = days.firstIndex(where: { calendar.isDate($0, inSameDayAs: today) }) { return i }
        return board.monday < today ? 6 : -1
    }

    private var profile: RateProfile {
        RateProfile(monthlyNetPay: monthlyNetPay,
                    weeklyWorkHours: weeklyWorkHours,
                    workDaysPerMonth: workDaysPerMonth,
                    dailyCommuteHours: dailyCommuteHours,
                    totalAssets: totalAssets,
                    annualReturnPercent: annualReturnPercent)
    }

    private var reading: WeeklyReading {
        WeeklyReading.compute(days: days,
                              throughIndex: throughIndex,
                              allCells: allCells,
                              recoveries: recoveries,
                              exchanges: exchanges,
                              monthlyNetPay: monthlyNetPay,
                              laborRate: profile.laborRate,
                              calendar: calendar)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Palette.bg.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 14) {
                        weekBar
                        readingPanel
                        recoveryPanel
                        principle
                    }
                    .padding(16)
                    .padding(.bottom, 60)
                }
                .scrollDismissesKeyboard(.interactively)
                .dismissesKeyboardOnTap()
            }
            .navigationTitle("주간 읽기")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Palette.bg, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar { KeyboardDoneButton() }
        }
        .tint(Palette.text)
    }

    // MARK: 주 이동

    private var weekBar: some View {
        HStack {
            Button { shift(-1) } label: { Image(systemName: "chevron.left") }
            Text(board.weekTitle(calendar: calendar))
                .font(.headline)
                .foregroundStyle(Palette.text)
                .frame(maxWidth: .infinity)
            Button { shift(1) } label: { Image(systemName: "chevron.right") }
                .disabled(board.monday >= Week.monday(of: .now, calendar: calendar))
        }
        .foregroundStyle(Palette.mute)
    }

    private func shift(_ delta: Int) {
        if let next = calendar.date(byAdding: .day, value: delta * 7, to: board.monday) { board.monday = next }
    }

    // MARK: 다섯 줄

    private var readingPanel: some View {
        Panel(title: "네 숫자는 합산하지 않습니다") {
            VStack(alignment: .leading, spacing: 16) {
                soldLine
                seedLine
                joyLine
                withdrawalLine
                fogLine
            }
        }
    }

    private var soldLine: some View {
        let r = reading
        return line(dot: Palette.sold) {
            if r.soldCells == 0 {
                Text("판 시간이 없는 주입니다.")
            } else {
                Text("노랑 \(r.soldCells)칸")
                    .fontWeight(.semibold)
                    .monospacedDigit()

                // 전표가 붙은 노랑 — 금액이 칸에서 직접 관측된다.
                if r.soldPricedCells > 0 {
                    Text("전표 \(r.soldPricedCells)칸에 \(Fmt.won(r.soldTotal)) · 칸당 실측 \(Fmt.won(r.soldPerCell))")
                        .monospacedDigit()
                    sub(r.soldTags.map { "\($0.tag) 칸당 \(Fmt.won($0.perCell))" }.joined(separator: " · "))
                    if r.soldTagsDiverge {
                        sub("단가가 다른 노랑이 섞여 있습니다. 어느 노랑을 줄일지가 여기서 나옵니다.")
                    }
                }

                // 월급 노랑 — 금액이 칸에 없고 그 달의 월급에서 배분된다.
                ForEach(r.salaryMonths) { m in
                    VStack(alignment: .leading, spacing: 3) {
                        Text("월급 \(m.cellsThisWeek)칸 · 칸당 \(Fmt.won(m.perCell)) · 시간당 \(Fmt.won(m.perHour))")
                            .monospacedDigit()
                        sub(m.isPartial
                            ? "\(m.label) 실수령 \(Fmt.won(m.monthlyPay)) 중 \(m.elapsedDays)/\(m.daysInMonth)일치 \(Fmt.won(m.pay))을 월급 칸 \(m.cellsInMonth)개(\(Fmt.hours(m.hoursInMonth)))로 나눔"
                            : "\(m.label) 실수령 \(Fmt.won(m.pay))을 월급 칸 \(m.cellsInMonth)개(\(Fmt.hours(m.hoursInMonth)))로 나눔")
                        if r.laborRate > 0 {
                            sub(gapSentence(soldRate: m.perHour, laborRate: r.laborRate), tint: Palette.sold)
                        }
                    }
                }
                if r.salaryCells > 0 && r.laborRate > 0 {
                    sub("출금 판단에는 여전히 구속 시급을 씁니다. 밀도가 올라간 것이지 한 시간을 되사는 값이 싸진 것은 아닙니다.")
                    sub("그 달에 아직 칠하지 않은 날이 있으면 이 값은 실제보다 높게 나옵니다.")
                }

                if r.soldPricedCells == 0 && r.salaryCells == 0 {
                    sub("아직 전표가 없습니다. 칸을 눌러 입금액을 붙이거나 월급 칸으로 표시하면 단가가 계산됩니다.")
                }
            }
        }
    }

    /// 판 시간 시급이 구속 시급보다 얼마나 높은지. 이 간극이 곧 "출근했지만 팔지 않은 시간"이다.
    private func gapSentence(soldRate: Double, laborRate: Double) -> String {
        guard laborRate > 0, soldRate > 0 else { return "" }
        let gap = (soldRate - laborRate) / laborRate * 100
        if gap < 1 {
            return "구속 시급 \(Fmt.won(laborRate))/h과 거의 같습니다. 매인 시간을 거의 다 팔고 있습니다."
        }
        // 두 배를 넘는 간극은 밀도가 아니라 대개 기록 누락이다. 그걸 성과로 읽으면 안 된다.
        if gap > 100 {
            return "구속 시급 \(Fmt.won(laborRate))/h의 \(Fmt.ratio(soldRate / laborRate))배입니다. 이 정도 차이는 대개 그 달을 아직 다 칠하지 않았다는 뜻입니다."
        }
        return "구속 시급 \(Fmt.won(laborRate))/h보다 \(Fmt.percent(gap)) 높습니다. 관측이지 판단이 아닙니다."
    }

    private var seedLine: some View {
        let r = reading
        return line(dot: Palette.seed) {
            if r.seedCells == 0 {
                Text("심은 시간이 없는 주입니다.")
            } else {
                Text("파랑 \(r.seedCells)칸")
                    .fontWeight(.semibold)
                    .monospacedDigit()
                Text("일일 평가 없음. 회수가 실현될 때만 소급합니다.")
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(r.seedTags) { t in
                        if t.recovered > 0 {
                            sub("\(t.tag): 전 기간 \(t.cellsAllTime)칸 · 회수 \(Fmt.won(t.recovered)) → 칸당 \(Fmt.won(t.perCell))")
                        } else {
                            sub("\(t.tag): \(t.cellsThisWeek)칸 · 회수 전 (0원이 정상)")
                        }
                    }
                }
            }
        }
    }

    private var joyLine: some View {
        let r = reading
        return line(dot: Palette.joy) {
            if r.joyCells == 0 {
                Text("누린 시간이 한 칸도 없습니다.")
                    .fontWeight(.semibold)
                sub("배당 없는 투자만 한 주입니다.")
            } else {
                Text("빨강 \(r.joyCells)칸, 배당 원가 \(Fmt.won(r.joyCost))")
                    .fontWeight(.semibold)
                    .monospacedDigit()
                sub("이 시간의 가치는 계산하지 않습니다. 원가만 압니다.")
            }
        }
    }

    private var withdrawalLine: some View {
        let r = reading
        return line(dot: Palette.care) {
            Text("출금")
                .fontWeight(.semibold)
            if r.withdrawals.isEmpty {
                sub("이번 주 출금 없음. 초록 칸을 눌러 지불액을 넣으면 여기 기록됩니다.")
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(r.withdrawals) { w in
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 5) {
                                Text("\(w.dayLabel) \(w.slotLabel) 칸을 \(Fmt.won(w.cost))에")
                                    .monospacedDigit()
                                ColorDot(color: w.from.tint)
                                Text("→")
                                ColorDot(color: w.to.tint)
                            }
                            sub("번÷산 \(Fmt.ratio(w.ratio)) · 순증 \(Fmt.hours(w.netHours, signed: true))",
                                tint: w.netHours >= 0 ? Palette.care : Palette.joy)
                        }
                    }
                }
                .font(.body)
            }
            if r.careCells > 0 {
                sub("초록 \(r.careCells)칸 · 운영비 \(Fmt.won(r.careCost))")
            }
        }
    }

    private var fogLine: some View {
        let r = reading
        return line(dot: Palette.fog) {
            if r.fogCells == 0 {
                Text("안개 없음.")
            } else {
                Text("안개 \(r.fogCells)칸")
                    .fontWeight(.semibold)
                    .monospacedDigit()
                sub("돈은 붙이지 않습니다. 개수만 셉니다. 지나간 \(r.pastCells)칸 중 \(r.fogCells)칸.")
            }
        }
    }

    private func line<C: View>(dot: Color, @ViewBuilder content: () -> C) -> some View {
        HStack(alignment: .top, spacing: 9) {
            ColorDot(color: dot).padding(.top, 5)
            VStack(alignment: .leading, spacing: 3) { content() }
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .font(.body)
        .foregroundStyle(Palette.text)
    }

    private func sub(_ text: String, tint: Color = Palette.mute) -> some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(tint)
            .monospacedDigit()
    }

    // MARK: 자산으로 넘김

    private var recoveryPanel: some View {
        Panel(title: "심은 것은 «자산»에서 본다") {
            VStack(alignment: .leading, spacing: 10) {
                Text("회수 기록은 «자산» 탭으로 옮겼습니다. 한 주가 아니라 자산의 수명을 단위로 읽어야 하는 숫자이기 때문입니다.")
                    .font(.body)
                    .foregroundStyle(Palette.mute)
                Text("거기서는 돈뿐 아니라 돌아온 시간과 배당 칸도 함께 셉니다. 그리고 아직 아무것도 돌려주지 않은 자산을 이름으로 말해 줍니다.")
                    .font(.body)
                    .foregroundStyle(Palette.mute)
            }
        }
    }

    // MARK: 원칙

    private var principle: some View {
        Panel(title: "왜 합산하지 않는가") {
            Text("판 시간, 심은 시간, 누린 시간, 돌본 시간은 단위가 다릅니다. 하나의 점수로 합치는 순간 올릴 대상이 생기고, 사람은 점수를 올리려고 삶을 바꿉니다. 재무제표가 매출과 자산과 비용을 한 칸에 더하지 않는 것과 같은 이유로, 이 화면은 나란히만 둡니다.")
                .font(.body)
                .foregroundStyle(Palette.mute)
        }
    }
}
