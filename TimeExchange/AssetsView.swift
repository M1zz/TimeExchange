import SwiftUI
import SwiftData

/// 자산 장부. 심은 시간이 무엇으로 돌아왔는지를 태그별로 본다.
///
/// 주간 읽기가 "이번 주에 무슨 일이 있었나"라면, 여기는 "넣은 것이 나왔나"다.
/// 시간 단위가 주가 아니라 자산의 수명이므로 화면을 따로 둔다.
struct AssetsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \TimeCell.day) private var allCells: [TimeCell]
    @Query(sort: \Recovery.date, order: .reverse) private var recoveries: [Recovery]

    @AppStorage("monthlyNetPay") private var monthlyNetPay = RateDefaults.monthlyNetPay
    @AppStorage("weeklyWorkHours") private var weeklyWorkHours = RateDefaults.weeklyWorkHours
    @AppStorage("workDaysPerMonth") private var workDaysPerMonth = RateDefaults.workDaysPerMonth
    @AppStorage("dailyCommuteHours") private var dailyCommuteHours = RateDefaults.dailyCommuteHours

    @State private var draftKind: [String: RecoveryKind] = [:]
    @State private var draftValue: [String: String] = [:]

    private var laborRate: Double {
        RateProfile(monthlyNetPay: monthlyNetPay,
                    weeklyWorkHours: weeklyWorkHours,
                    workDaysPerMonth: workDaysPerMonth,
                    dailyCommuteHours: dailyCommuteHours,
                    totalAssets: 0,
                    annualReturnPercent: 0).laborRate
    }

    private var assets: [AssetLedger] {
        AssetLedger.build(cells: allCells, recoveries: recoveries)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Palette.bg.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 14) {
                        if assets.isEmpty {
                            empty
                        } else {
                            ForEach(assets) { card(for: $0) }
                            principle
                        }
                    }
                    .padding(16)
                    .padding(.bottom, 60)
                }
                .scrollDismissesKeyboard(.interactively)
                .dismissesKeyboardOnTap()
            }
            .navigationTitle("자산")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Palette.bg, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar { KeyboardDoneButton() }
        }
        .tint(Palette.text)
    }

    private var empty: some View {
        Panel(title: "아직 심은 것이 없습니다") {
            Text("색칠판에서 칸을 파랑으로 칠하고 «어느 자산에 심었나»에 이름을 붙이면 여기 한 장이 생깁니다. 그 다음부터는 넣은 것이 무엇으로 돌아왔는지를 이 화면이 대신 기억합니다.")
                .font(.body)
                .foregroundStyle(Palette.mute)
        }
    }

    // MARK: - 자산 한 장

    private func card(for a: AssetLedger) -> some View {
        Panel {
            VStack(alignment: .leading, spacing: 14) {
                header(a)
                Divider().overlay(Palette.line)
                returns(a)
                Divider().overlay(Palette.line)
                status(a)
                if !a.closed { entry(a) }
                history(a)
            }
        }
        .opacity(a.closed ? 0.6 : 1)
    }

    private func header(_ a: AssetLedger) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                ColorDot(color: Palette.seed)
                Text(a.tag)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Palette.text)
                Spacer()
                if a.closed {
                    Text("접음")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Palette.mute)
                } else if let age = a.age(today: .now) {
                    Text(age == 0 ? "이번 주에 심음" : "심은 지 \(age)주")
                        .font(.subheadline)
                        .foregroundStyle(Palette.mute)
                }
            }
            Text("심은 시간 \(a.cells)칸 · \(Fmt.hours(a.hours))")
                .font(.body)
                .monospacedDigit()
                .foregroundStyle(Palette.mute)
        }
    }

    /// 돌아온 것들. 단위가 달라 더하지 않고 나란히 둔다.
    private func returns(_ a: AssetLedger) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            returnRow(tint: Palette.sold, label: "돈으로",
                      value: a.money > 0 ? Fmt.won(a.money) : "0원",
                      detail: a.moneyPerHour.map { "시간당 \(Fmt.won($0))" })
            returnRow(tint: Palette.care, label: "시간으로",
                      value: Fmt.hours(a.timeBack),
                      detail: a.timeBack > 0 ? "앞으로 안 써도 되는 시간" : nil)
            returnRow(tint: Palette.joy, label: "배당으로",
                      value: a.dividendCells > 0 ? "빨강 \(a.dividendCells)칸 · \(Fmt.hours(a.dividendHours))" : "빨강 0칸",
                      detail: a.dividendCells > 0 ? "값은 매기지 않습니다. 세기만 합니다." : nil)
        }
    }

    private func returnRow(tint: Color, label: String, value: String, detail: String?) -> some View {
        HStack(alignment: .top, spacing: 10) {
            ColorDot(color: tint).padding(.top, 5)
            Text(label)
                .font(.body)
                .foregroundStyle(Palette.mute)
                .frame(width: 76, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
                Text(value).font(.body.weight(.semibold)).monospacedDigit().foregroundStyle(Palette.text)
                if let detail {
                    Text(detail).font(.subheadline).monospacedDigit().foregroundStyle(Palette.mute)
                }
            }
        }
    }

    // MARK: - 상태

    @ViewBuilder
    private func status(_ a: AssetLedger) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(statusLines(a).enumerated()), id: \.offset) { _, line in
                Text(line.text)
                    .font(.subheadline)
                    .foregroundStyle(line.tint)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(10)
        .background(Palette.bg, in: RoundedRectangle(cornerRadius: 10))
    }

    private func statusLines(_ a: AssetLedger) -> [(text: String, tint: Color)] {
        if a.closed {
            return [("접었습니다. 심은 \(Fmt.hours(a.hours))는 회수되지 않았습니다.", Palette.text),
                    ("실패가 아니라 정보입니다. 접은 자산이 있어야 남은 자산의 숫자가 정직해집니다.", Palette.mute)]
        }

        var lines: [(String, Color)] = []

        if let perHour = a.moneyPerHour, laborRate > 0 {
            let ratio = perHour / laborRate
            lines.append(("심은 시간당 \(Fmt.won(perHour)). 구속 시급 \(Fmt.won(laborRate))의 \(Fmt.ratio(ratio))배입니다.", Palette.text))
            lines.append((ratio >= 1
                          ? "판 것보다 나았습니다. 다만 자산은 계속 회수되므로 이 배수는 앞으로 더 오릅니다."
                          : "아직 파는 것보다 못합니다. 자산은 계속 회수되므로 지금 접을 이유는 되지 않습니다.",
                          Palette.mute))
        } else if a.hasReturn {
            lines.append(("돌아오기 시작했습니다.", Palette.text))
            if a.money == 0 {
                lines.append(("돈으로는 아직 0원입니다. 시간과 배당으로 먼저 돌아오는 자산도 있습니다.", Palette.mute))
            }
        } else {
            let age = a.age(today: .now) ?? 0
            lines.append(("\(age)주째, 아직 아무것도 돌아오지 않았습니다.", Palette.text))
            switch age {
            case ..<4:
                lines.append(("이릅니다. 파랑은 원래 늦게 돌아옵니다. 지금 평가할 것이 없는 것이 정상입니다.", Palette.mute))
            case 4..<13:
                lines.append(("아직 이르다고 볼 수 있습니다. 다만 무엇이 돌아와야 하는지는 지금 정해 두는 편이 낫습니다.", Palette.mute))
            default:
                lines.append(("접을지, 더 심을지 정할 때입니다. 결정을 미루는 것도 이 자산에 시간을 쓰는 일입니다.", Palette.sold))
            }
        }

        if let idle = a.idle(today: .now), idle >= 4, !a.hasReturn {
            lines.append(("마지막으로 심은 지 \(idle)주. 심는 것도 멈춰 있습니다.", Palette.sold))
        }
        return lines.map { (text: $0.0, tint: $0.1) }
    }

    // MARK: - 회수 기록

    private func entry(_ a: AssetLedger) -> some View {
        let kind = draftKind[a.tag] ?? .money
        return VStack(alignment: .leading, spacing: 8) {
            Picker("회수 종류", selection: Binding(
                get: { draftKind[a.tag] ?? .money },
                set: { draftKind[a.tag] = $0 }
            )) {
                ForEach(RecoveryKind.allCases) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented)

            Text(kind.detail)
                .font(.subheadline)
                .foregroundStyle(Palette.mute)

            HStack(spacing: 8) {
                if kind != .closed {
                    TextField(kind == .money ? "회수액 (원)" : "돌아온 시간 (h)",
                              text: Binding(get: { draftValue[a.tag] ?? "" },
                                            set: { draftValue[a.tag] = $0 }))
                        .keyboardType(kind == .money ? .numberPad : .decimalPad)
                        .multilineTextAlignment(.trailing)
                        .padding(10)
                        .background(Palette.bg, in: RoundedRectangle(cornerRadius: 8))
                        .foregroundStyle(Palette.text)
                }
                Button(kind == .closed ? "접기" : "기록") { record(a, kind: kind) }
                    .font(.body)
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(Palette.bg, in: RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Palette.line))
                    .foregroundStyle(kind == .closed ? Palette.joy : Palette.text)
            }

            if kind == .money, let v = Double((draftValue[a.tag] ?? "").filter(\.isNumber)), v > 0 {
                Text(Fmt.korean(v) + "원")
                    .font(.subheadline)
                    .foregroundStyle(Palette.mute)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
    }

    private func record(_ a: AssetLedger, kind: RecoveryKind) {
        let raw = (draftValue[a.tag] ?? "").filter { $0.isNumber || $0 == "." }
        switch kind {
        case .money:
            guard let v = Double(raw), v > 0 else { return }
            context.insert(Recovery(tag: a.tag, kind: .money, won: v))
        case .time:
            guard let v = Double(raw), v > 0 else { return }
            context.insert(Recovery(tag: a.tag, kind: .time, hours: v))
        case .closed:
            context.insert(Recovery(tag: a.tag, kind: .closed))
        }
        draftValue[a.tag] = ""
    }

    @ViewBuilder
    private func history(_ a: AssetLedger) -> some View {
        let mine = recoveries.filter { $0.tag == a.tag }
        if !mine.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(mine) { rec in
                    HStack {
                        Text("\(rec.kind.label) \(rec.summary)")
                            .monospacedDigit()
                        Spacer()
                        Text(rec.date.formatted(.dateTime.month().day()))
                        Button { context.delete(rec) } label: { Image(systemName: "xmark.circle.fill") }
                            .buttonStyle(.plain)
                    }
                    .font(.subheadline)
                    .foregroundStyle(Palette.mute)
                }
            }
        }
    }

    // MARK: - 원칙

    private var principle: some View {
        Panel(title: "돌아온 것도 합산하지 않습니다") {
            VStack(alignment: .leading, spacing: 10) {
                Text("돈과 시간과 배당은 단위가 다릅니다. 셋을 하나의 «수익»으로 합치면 그 순간 올릴 대상이 생기고, 자산을 만드는 이유가 숫자가 됩니다.")
                    .font(.body)
                    .foregroundStyle(Palette.mute)
                Text("배당 칸은 세기만 하고 값을 매기지 않습니다. 내가 만든 것 덕분에 즐거웠던 시간에 가격을 붙이면, 빨강에 가격을 붙이지 않는 이유가 그대로 무너집니다.")
                    .font(.body)
                    .foregroundStyle(Palette.mute)
                Text("이 화면이 확실하게 말하는 것은 하나뿐입니다. 무엇이 아직 아무것도 돌려주지 않았는가.")
                    .font(.body)
                    .foregroundStyle(Palette.text)
            }
        }
    }
}
