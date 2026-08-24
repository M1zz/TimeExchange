import SwiftUI
import SwiftData

struct SettingsView: View {
    @AppStorage("monthlyNetPay") private var monthlyNetPay = RateDefaults.monthlyNetPay
    @AppStorage("weeklyWorkHours") private var weeklyWorkHours = RateDefaults.weeklyWorkHours
    @AppStorage("workDaysPerMonth") private var workDaysPerMonth = RateDefaults.workDaysPerMonth
    @AppStorage("dailyCommuteHours") private var dailyCommuteHours = RateDefaults.dailyCommuteHours
    @AppStorage("totalAssets") private var totalAssets = RateDefaults.totalAssets
    @AppStorage("annualReturnPercent") private var annualReturnPercent = RateDefaults.annualReturnPercent

    @Environment(\.modelContext) private var context
    @Query private var cells: [TimeCell]
    @State private var confirmReset = false
    @State private var confirmClearBoard = false
    @State private var confirmSeed = false

    private var profile: RateProfile {
        RateProfile(monthlyNetPay: monthlyNetPay,
                    weeklyWorkHours: weeklyWorkHours,
                    workDaysPerMonth: workDaysPerMonth,
                    dailyCommuteHours: dailyCommuteHours,
                    totalAssets: totalAssets,
                    annualReturnPercent: annualReturnPercent)
    }

    var body: some View {
        NavigationStack {
            Form {
                incomeSection
                derivedRateSection
                soldRateSection
                assetSection
                assetRateSection
                guideSection
                Section("데모") {
                    Button("데모 데이터 채우기") { confirmSeed = true }
                    Text("단가가 다른 노랑 세 개와, 회수된 파랑·회수 전 파랑이 들어 있는 두 주치 기록입니다. 이 장부가 무엇을 말하는지 보려는 용도이며, 기존 기록 위에 덧씌워집니다.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Section {
                    Button("출금 기록만 삭제", role: .destructive) { confirmReset = true }
                    Button("색칠판·회수까지 전부 삭제", role: .destructive) { confirmClearBoard = true }
                }
            }
            .navigationTitle("환율 설정")
            .scrollDismissesKeyboard(.interactively)
            .dismissesKeyboardOnTap()
            .toolbar { KeyboardDoneButton() }
            .confirmationDialog("출금 기록을 모두 삭제할까요?", isPresented: $confirmReset, titleVisibility: .visible) {
                Button("삭제", role: .destructive) { deleteExchanges() }
            }
            .confirmationDialog("칠한 칸, 전표, 회수 기록까지 전부 삭제할까요?", isPresented: $confirmClearBoard, titleVisibility: .visible) {
                Button("전부 삭제", role: .destructive) { deleteEverything() }
            } message: {
                Text("되돌릴 수 없습니다.")
            }
            .confirmationDialog("데모 데이터를 채울까요?", isPresented: $confirmSeed, titleVisibility: .visible) {
                Button("채우기") { SeedData.install(into: context) }
            } message: {
                Text("이번 주와 지난 주에 예시 기록이 들어갑니다. 같은 칸에 이미 칠한 것이 있으면 겹칩니다.")
            }
        }
    }

    // MARK: - 월급

    @ViewBuilder
    private var incomeSection: some View {
        Section("월급") {
            LabeledContent("월 실수령액 (세후)") {
                numberField(value: $monthlyNetPay, unit: "원")
            }
            LabeledContent("주당 근무시간") {
                numberField(value: $weeklyWorkHours, unit: "시간")
            }
            LabeledContent("월 근무일수") {
                numberField(value: $workDaysPerMonth, unit: "일")
            }
            LabeledContent("하루 통근 (왕복)") {
                numberField(value: $dailyCommuteHours, unit: "시간")
            }
            Text("세금·4대보험을 뗀 뒤 실제로 통장에 꽂히는 금액을 넣으세요. 세전 연봉으로 넣으면 시급이 30~40% 부풀려집니다. 통근은 급여에 안 잡히지만 회사 때문에 쓰는 시간이므로 판 시간에 포함합니다.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - 도출된 노동 환율

    @ViewBuilder
    private var derivedRateSection: some View {
        Section("내 시급 (노동 환율)") {
            LabeledContent("월 근무시간", value: Fmt.hours(profile.monthlyWorkHours))
            LabeledContent("월 통근시간", value: Fmt.hours(profile.monthlyCommuteHours))
            LabeledContent("월 구속시간", value: Fmt.hours(profile.monthlyCommittedHours))
                .fontWeight(.semibold)

            HStack {
                Text("1시간의 값")
                Spacer()
                Text(Fmt.won(profile.laborRate) + "/h")
                    .font(.title3.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(Color.orange)
            }

            if profile.monthlyCommuteHours > 0 {
                Text("통근을 빼고 계산하면 \(Fmt.won(profile.rateIgnoringCommute))/h로 \(Fmt.percent(profile.commuteInflationPercent)) 부풀려집니다. 환율이 높을수록 모든 출금이 이득처럼 보이므로 낮게 잡는 편이 안전합니다.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - 판 시간 시급

    /// 이번 달 월급 칸. 출근한 시간 중 실제로 노랑으로 칠한 것만 센다.
    private var salaryCellsThisMonth: [TimeCell] {
        let key = Week.monthKey(of: .now)
        return cells.filter { $0.color == .sold && $0.fromSalary && Week.monthKey(of: $0.day) == key }
    }

    private var soldHoursThisMonth: Double {
        salaryCellsThisMonth.reduce(0) { $0 + $1.slot.hours }
    }

    private var monthSpan: (elapsed: Int, total: Int) {
        WeeklyReading.monthSpan(key: Week.monthKey(of: .now), today: .now)
    }

    /// 이번 달에서 지금까지 벌어들인 몫. 아직 지나지 않은 날의 월급까지 나누면 값이 부풀려진다.
    private var paySoFar: Double {
        monthSpan.total > 0 ? monthlyNetPay * Double(monthSpan.elapsed) / Double(monthSpan.total) : 0
    }

    /// 월급을 실제로 판 시간으로만 나눈 값. 관측값이며 출금 판단에는 쓰지 않는다.
    private var soldRate: Double {
        soldHoursThisMonth > 0 ? paySoFar / soldHoursThisMonth : 0
    }

    @ViewBuilder
    private var soldRateSection: some View {
        Section("판 시간 시급 (이번 달)") {
            if salaryCellsThisMonth.isEmpty {
                Text("아직 월급 칸이 없습니다. 색칠판에서 출근한 시간을 노랑으로 칠하고 전표에서 «이 칸은 월급에서 나옵니다»를 켜면, 매인 시간이 아니라 실제로 판 시간으로 나눈 시급이 여기 나옵니다.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                LabeledContent("이번 달 월급 칸", value: "\(salaryCellsThisMonth.count)칸 · \(Fmt.hours(soldHoursThisMonth))")
                LabeledContent("지금까지의 급여", value: "\(monthSpan.elapsed)/\(monthSpan.total)일 · \(Fmt.won(paySoFar))")

                HStack {
                    Text("판 시간 시급")
                    Spacer()
                    Text(Fmt.won(soldRate) + "/h")
                        .font(.title3.weight(.bold))
                        .monospacedDigit()
                        .foregroundStyle(Color.orange)
                }
                LabeledContent("구속 시급", value: Fmt.won(profile.laborRate) + "/h")
                if profile.laborRate > 0 {
                    LabeledContent("간극", value: Fmt.percent((soldRate - profile.laborRate) / profile.laborRate * 100))
                }

                Text("출근한 시간을 전부 노랑으로 칠하지 않으면 이 값은 올라갑니다. 판 시간의 밀도가 높다는 뜻이며, 그 자체로는 좋은 신호입니다.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("다만 출금 판단에는 쓰지 않습니다. 회사는 판 시간이 아니라 매인 시간 전체에 돈을 주기 때문입니다. 이 값으로 판단하면 모든 출금이 이득으로 보입니다.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("이번 달에 아직 칠하지 않은 날이 있으면 이 값은 실제보다 높게 나옵니다.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - 자산

    @ViewBuilder
    private var assetSection: some View {
        Section("자산") {
            LabeledContent("총 자산") {
                numberField(value: $totalAssets, unit: "원")
            }
            LabeledContent("연 기대수익률") {
                numberField(value: $annualReturnPercent, unit: "%")
            }
        }
    }

    @ViewBuilder
    private var assetRateSection: some View {
        Section("자산 환율 (돈이 버는 시급)") {
            HStack {
                Text("1시간에 버는 돈")
                Spacer()
                Text(Fmt.won(profile.assetRate) + "/h")
                    .font(.title3.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(Color.teal)
            }
            Text("자산 × 수익률을 1년 8,760시간으로 나눈 값입니다. 근무시간이 아니라 달력 시간으로 나누는 이유는 자산이 자는 동안에도 일하기 때문입니다. 이 값은 참고 지표일 뿐, 출금 순증 계산에는 노동 환율만 씁니다.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - 안내

    @ViewBuilder
    private var guideSection: some View {
        Section("이 환율이 쓰이는 곳") {
            Text("초록 칸을 돈으로 사서 다른 색으로 바꿀 때, 그 거래의 순증을 이 노동 환율로 계산합니다. 색칠판의 나머지 색에는 이 숫자가 닿지 않습니다.")
                .foregroundStyle(.secondary)
            Text("번 ÷ 산 > 1 : 시간이 실제로 늘어남")
            Text("번 ÷ 산 = 1 : 시간이 이동만 함")
            Text("번 ÷ 산 < 1 : 다른 날에서 빌려옴")
        }
        .font(.body)
    }

    // MARK: - 입력 필드

    private func numberField(value: Binding<Double>, unit: String) -> some View {
        VStack(alignment: .trailing, spacing: 3) {
            HStack(spacing: 4) {
                TextField(unit, value: value, format: .number)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                Text(unit)
                    .foregroundStyle(.secondary)
            }
            // 월급과 자산은 자릿수가 커서 눈으로는 틀린 걸 못 잡는다.
            if unit == "원", value.wrappedValue > 0 {
                Text(Fmt.korean(value.wrappedValue) + "원")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func deleteExchanges() {
        do {
            try context.delete(model: Exchange.self)
        } catch {
            print("출금 기록 삭제 실패: \(error)")
        }
    }

    private func deleteEverything() {
        do {
            try context.delete(model: Exchange.self)
            try context.delete(model: TimeCell.self)
            try context.delete(model: Recovery.self)
        } catch {
            print("전체 삭제 실패: \(error)")
        }
    }
}
