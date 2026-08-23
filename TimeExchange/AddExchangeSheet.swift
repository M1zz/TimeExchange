import SwiftUI
import SwiftData

struct AddExchangeSheet: View {
    let kind: ExchangeKind
    let myRate: Double
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var hours: Double = 1
    @State private var won: Double = 0
    @State private var rate: Double = 0

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(titlePlaceholder, text: $title)
                }
                if kind == .deposit {
                    depositSections
                } else {
                    withdrawalSections
                }
            }
            .navigationTitle(kind.label + " · " + kind.subtitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .onAppear { if kind == .deposit { rate = myRate } }
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private var depositSections: some View {
        Section("판 시간") {
            Stepper(value: $hours, in: 0.5...24, step: 0.5) {
                LabeledContent("시간", value: Fmt.hours(hours))
            }
            LabeledContent("환율 (시급)") {
                amountField(value: $rate)
            }
        }
        Section("입금액") {
            LabeledContent("저축되는 돈", value: Fmt.won(hours * rate))
                .fontWeight(.semibold)
            Text("이 돈은 \(Fmt.hours(hours))을 저장한 것입니다. 오늘 하루 길이에는 영향이 없습니다.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var withdrawalSections: some View {
        Section("쓴 돈") {
            LabeledContent("지출") {
                amountField(value: $won)
            }
            Stepper(value: $hours, in: 0.25...24, step: 0.25) {
                LabeledContent("돌려받은 시간", value: Fmt.hours(hours))
            }
        }
        Section("이 거래의 환율") {
            LabeledContent("산 시급", value: Fmt.won(boughtRate) + "/h")
            LabeledContent("번 시급", value: Fmt.won(myRate) + "/h")
            LabeledContent("번 ÷ 산", value: Fmt.ratio(ratio))
                .foregroundStyle(ratio >= 1 ? Color.teal : Color.red)
            LabeledContent("순증", value: Fmt.hours(netHours, signed: true))
                .foregroundStyle(netHours >= 0 ? Color.teal : Color.red)
            Text(ratioExplanation)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("취소") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
            Button("기록") { save() }.disabled(!valid)
        }
    }

    private func amountField(value: Binding<Double>) -> some View {
        TextField("원", value: value, format: .number)
            .keyboardType(.numberPad)
            .multilineTextAlignment(.trailing)
    }

    // MARK: - Derived values

    private var titlePlaceholder: String {
        kind == .deposit ? "예: 멘토링, 외주" : "예: 가사 대행, 택시"
    }

    /// 이 거래에서 산 시급. 돈 ÷ 돌려받은 시간.
    private var boughtRate: Double {
        hours > 0 ? won / hours : 0
    }

    /// 번 시급 ÷ 산 시급. 1보다 커야 시간이 실제로 늘어난다.
    private var ratio: Double {
        boughtRate > 0 ? myRate / boughtRate : 0
    }

    /// 돌려받은 시간 − 그 돈을 벌려고 쓴 시간.
    private var netHours: Double {
        myRate > 0 ? hours - won / myRate : 0
    }

    private var ratioExplanation: String {
        ratio >= 1
        ? "내 시급보다 싸게 샀습니다. 시간이 실제로 늘어납니다."
        : "내 시급보다 비싸게 샀습니다. 하루는 길어진 느낌이지만 다른 날에서 빌려온 시간입니다."
    }

    private var valid: Bool {
        kind == .deposit ? (hours > 0 && rate > 0) : (hours > 0 && won > 0)
    }

    private func save() {
        let ex = Exchange(kind: kind,
                          title: title,
                          won: kind == .deposit ? hours * rate : won,
                          hours: hours,
                          myRateAtTime: myRate)
        context.insert(ex)
        dismiss()
    }
}
