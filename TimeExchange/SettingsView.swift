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
    @State private var confirmReset = false

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
                assetSection
                assetRateSection
                guideSection
                Section {
                    Button("모든 거래 삭제", role: .destructive) { confirmReset = true }
                }
            }
            .navigationTitle("환율 설정")
            .confirmationDialog("모든 거래를 삭제할까요?", isPresented: $confirmReset, titleVisibility: .visible) {
                Button("삭제", role: .destructive) { deleteAll() }
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
                .font(.caption)
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
                    .font(.caption)
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
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - 안내

    @ViewBuilder
    private var guideSection: some View {
        Section("환율 읽는 법") {
            Text("번 ÷ 산 > 1 : 시간이 실제로 늘어남")
            Text("번 ÷ 산 = 1 : 시간이 이동만 함")
            Text("번 ÷ 산 < 1 : 다른 날에서 빌려옴")
        }
        .font(.footnote)
    }

    // MARK: - 입력 필드

    private func numberField(value: Binding<Double>, unit: String) -> some View {
        HStack(spacing: 4) {
            TextField(unit, value: value, format: .number)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
            Text(unit)
                .foregroundStyle(.secondary)
        }
    }

    private func deleteAll() {
        do {
            try context.delete(model: Exchange.self)
        } catch {
            print("거래 전체 삭제 실패: \(error)")
        }
    }
}
