import SwiftUI
import SwiftData

/// 칸 하나의 전표. 색을 고르는 것과 전표를 쓰는 것은 한 번의 판단이므로 한 시트에서 한다.
/// 고른 색에 따라 아래가 통째로 바뀌고, 그 다름이 회계 원칙이다.
struct LedgerSheet: View {
    let day: Date
    let slot: Slot
    let cell: TimeCell?
    let seedTags: [String]
    let laborRate: Double

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    /// nil = 안개. 저장하면 칸이 지워진다.
    @State private var color: TimeColor?
    @State private var wonText = ""
    @State private var tagText = ""
    /// 노랑 전용 — 이 칸의 돈이 월급에서 나오는가.
    @State private var fromSalary = false
    // 초록 전용 — 출금
    @State private var costText = ""
    @State private var toColor: TimeColor?
    @State private var hours: Double = 0

    init(day: Date, slot: Slot, cell: TimeCell?, seedTags: [String], laborRate: Double) {
        self.day = day
        self.slot = slot
        self.cell = cell
        self.seedTags = seedTags
        self.laborRate = laborRate
        _color = State(initialValue: cell?.color)
        _hours = State(initialValue: slot.hours)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section { whereLine }.listRowBackground(Palette.panel)
                palette
                fields
            }
            .scrollContentBackground(.hidden)
            .background(Palette.bg)
            .scrollDismissesKeyboard(.interactively)
            .dismissesKeyboardOnTap()
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("취소") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("저장") { save() } }
                KeyboardDoneButton()
            }
        }
        .presentationDetents([.medium, .large])
        .onAppear(perform: load)
        .onChange(of: color) { _, _ in colorChanged() }
    }

    private var title: String {
        guard let color else { return "안개" }
        return color.label + " — " + color.account
    }

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "M월 d일 EEEE"
        return f
    }()

    private var whereLine: some View {
        Text("\(Self.dayFormatter.string(from: day)) · \(slot.label) \(slot.clock)")
            .font(.body)
            .foregroundStyle(Palette.mute)
    }

    // MARK: 색 고르기

    private var palette: some View {
        Section {
            HStack(spacing: 4) {
                ForEach(TimeColor.allCases) { c in
                    chip(tint: c.tint, label: c.label, on: color == c) { color = c }
                }
                chip(tint: Palette.fog, label: "안개", on: color == nil) { color = nil }
            }
            .padding(.vertical, 4)

            if willDiscardLedger {
                Label("색을 바꾸면 이 칸에 붙어 있던 전표는 지워집니다. 계정과목이 바뀌었는데 전표를 이월하는 것은 회계상 틀리기 때문입니다.",
                      systemImage: "exclamationmark.triangle")
                    .font(.subheadline)
                    .foregroundStyle(Palette.sold)
            }
        }
        .listRowBackground(Palette.panel)
    }

    /// 저장하면 기존 전표가 사라지는가.
    private var willDiscardLedger: Bool {
        guard let cell, cell.hasLedger else { return false }
        return color != cell.color
    }

    private func chip(tint: Color, label: String, on: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Circle()
                    .fill(tint)
                    .frame(width: 28, height: 28)
                    .overlay(Circle().strokeBorder(on ? Palette.text : .clear, lineWidth: 2))
                Text(label).font(.footnote).lineLimit(1).minimumScaleFactor(0.75)
            }
            .foregroundStyle(on ? Palette.text : Palette.mute)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    // MARK: 색마다 다른 전표

    @ViewBuilder
    private var fields: some View {
        switch color {
        case .none:  fogFields
        case .sold:  soldFields
        case .seed:  seedFields
        case .joy:   joyFields
        case .care:  careFields
        }
    }

    /// 안개 — 붙일 자리 자체가 없다.
    @ViewBuilder
    private var fogFields: some View {
        Section {
            Text("안개에는 전표를 붙이지 않습니다.")
                .font(.headline)
                .foregroundStyle(Palette.text)
            Text("기억이 안 나면 누수고, 판단이 안 서면 미결입니다. 여기에 돈을 붙이는 순간 이 앱은 죄책감 장치가 됩니다. 안개는 개수만 셉니다.")
                .font(.body)
                .foregroundStyle(Palette.mute)
        }
        .listRowBackground(Palette.panel)
    }

    @ViewBuilder
    private var soldFields: some View {
        Section {
            Toggle(isOn: $fromSalary) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("이 칸은 월급에서 나옵니다").foregroundStyle(Palette.text)
                    Text("출근해서 판 시간").font(.subheadline).foregroundStyle(Palette.mute)
                }
            }
            .tint(Palette.sold)
        }
        .listRowBackground(Palette.panel)

        if fromSalary {
            Section {
                Text("월급은 칸마다 입금되지 않습니다. 그래서 여기에도 금액 칸이 없습니다. 그 달의 실수령액을 그 달의 월급 칸 전체로 나눕니다.")
                    .font(.body)
                    .foregroundStyle(Palette.mute)
                Text("출근한 시간을 전부 노랑으로 칠할 필요는 없습니다. 회사에서 배운 시간은 파랑, 회의와 잡무는 초록, 기억나지 않는 시간은 안개입니다. 노랑이 줄면 칸당 단가는 올라갑니다.")
                    .font(.subheadline)
                    .foregroundStyle(Palette.mute)
            }
            .listRowBackground(Palette.panel)
        } else {
            Section("이 칸의 입금액") {
                amountField(text: $wonText, placeholder: "예: 120000")
            }
            .listRowBackground(Palette.panel)
            Section("무엇을 팔았나") {
                TextField("예: 멘토링, 외주, 강의", text: $tagText)
            }
            .listRowBackground(Palette.panel)
            Section {
                Text("노랑은 유일하게 돈이 관측되는 색입니다. 칸이 쌓이면 추정 시급이 실측 시급이 됩니다. 태그별로 단가가 갈리면 어느 노랑을 줄일지가 거기서 나옵니다.")
                    .font(.body)
                    .foregroundStyle(Palette.mute)
            }
            .listRowBackground(Palette.panel)
        }
    }

    @ViewBuilder
    private var seedFields: some View {
        Section("어느 자산에 심었나") {
            TextField("예: 환전소 앱, devkoan 글", text: $tagText)
            if !seedTags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(seedTags, id: \.self) { tag in
                            Button(tag) { tagText = tag }
                                .font(.subheadline)
                                .padding(.horizontal, 10).padding(.vertical, 5)
                                .background(Palette.seed.opacity(0.18), in: Capsule())
                                .foregroundStyle(Palette.text)
                        }
                    }
                }
            }
        }
        .listRowBackground(Palette.panel)
        Section {
            Text("파랑은 오늘 0원이 정상입니다. 금액 칸이 없는 것은 실수가 아니라 원칙입니다. 심은 시간을 매일 평가하면 아직 값이 없는 일을 그만두게 됩니다.")
                .font(.body)
                .foregroundStyle(Palette.mute)
            Text("수익이 실현되면 «주간 읽기»의 회수 기록에서 이 태그의 파란 칸 전체로 소급 배분됩니다.")
                .font(.subheadline)
                .foregroundStyle(Palette.mute)
        }
        .listRowBackground(Palette.panel)
    }

    @ViewBuilder
    private var joyFields: some View {
        Section("이 시간에 쓴 돈") {
            amountField(text: $wonText, placeholder: "없으면 비움")
        }
        .listRowBackground(Palette.panel)

        Section("어느 자산에서 나왔나 (선택)") {
            TextField("내가 만든 것 덕분이라면 그 이름", text: $tagText)
            if !seedTags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(seedTags, id: \.self) { tag in
                            Button(tag) { tagText = tag }
                                .font(.subheadline)
                                .padding(.horizontal, 10).padding(.vertical, 5)
                                .background(Palette.seed.opacity(0.18), in: Capsule())
                                .foregroundStyle(Palette.text)
                        }
                    }
                }
            }
            Text("그냥 논 시간이면 비워 둡니다. 심은 것이 즐거운 시간으로 돌아온 경우에만 잇습니다. «자산» 탭에서 배당 칸으로 세어집니다.")
                .font(.subheadline)
                .foregroundStyle(Palette.mute)
        }
        .listRowBackground(Palette.panel)
        Section {
            Text("빨강에는 원가만 붙입니다. 이 시간의 가치는 계산하지 않습니다. 가격이 붙는 순간 누리는 능력이 죽습니다.")
                .font(.body)
                .foregroundStyle(Palette.mute)
        }
        .listRowBackground(Palette.panel)
    }

    @ViewBuilder
    private var careFields: some View {
        Section("운영비") {
            amountField(text: $wonText, placeholder: "없으면 비움")
        }
        .listRowBackground(Palette.panel)

        Section("이 칸을 돈으로 사서 다른 색으로 바꾸기 · 출금") {
            amountField(text: $costText, placeholder: "지불액 (예: 45000)")
            HStack(spacing: 8) {
                swapButton(.seed, "심었다로")
                swapButton(.joy, "누렸다로")
            }
            Stepper(value: $hours, in: 0.5...12, step: 0.5) {
                HStack {
                    Text("돌려받은 시간").foregroundStyle(Palette.text)
                    Spacer()
                    Text(Fmt.hours(hours)).monospacedDigit().foregroundStyle(Palette.mute)
                }
            }
        }
        .listRowBackground(Palette.panel)

        if let cost = parse(costText), cost > 0, laborRate > 0 {
            let boughtRate = cost / max(hours, 0.01)
            let net = hours - cost / laborRate
            Section("이 출금의 환율") {
                row("산 시급", Fmt.won(boughtRate) + "/h")
                row("번 시급", Fmt.won(laborRate) + "/h")
                row("번 ÷ 산", Fmt.ratio(laborRate / max(boughtRate, 0.01)),
                    tint: boughtRate <= laborRate ? Palette.care : Palette.joy)
                row("순증", Fmt.hours(net, signed: true), tint: net >= 0 ? Palette.care : Palette.joy)
                Text(net >= 0
                     ? "내 시급보다 싸게 샀습니다. 시간이 실제로 늘어납니다."
                     : "내 시급보다 비싸게 샀습니다. 하루는 길어진 느낌이지만 다른 날에서 빌려온 시간입니다.")
                    .font(.subheadline)
                    .foregroundStyle(Palette.mute)
            }
            .listRowBackground(Palette.panel)
        }

        Section {
            Text("가사 대행이 이 거래입니다. 초록 칸을 지불액으로 지우고, 비워진 칸에 무엇이 들어왔는지를 새 색으로 기록합니다. 색을 고르지 않으면 운영비만 저장됩니다.")
                .font(.body)
                .foregroundStyle(Palette.mute)
        }
        .listRowBackground(Palette.panel)
    }

    private func swapButton(_ target: TimeColor, _ label: String) -> some View {
        Button {
            toColor = (toColor == target) ? nil : target
        } label: {
            Text(label)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Palette.ink)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background(target.tint, in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(toColor == target ? Palette.text : .clear, lineWidth: 2))
        }
        .buttonStyle(.plain)
    }

    // MARK: 입력

    private func amountField(text: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .trailing, spacing: 3) {
            HStack {
                TextField(placeholder, text: text)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .foregroundStyle(Palette.text)
                Text("원").foregroundStyle(Palette.mute)
            }
            // 0을 하나 더 치거나 덜 치는 실수는 숫자를 다시 봐서는 잘 안 잡힌다. 소리내어 읽어야 잡힌다.
            if let v = parse(text.wrappedValue), v > 0 {
                Text(Fmt.korean(v) + "원")
                    .font(.subheadline)
                    .foregroundStyle(Palette.mute)
            }
        }
    }

    private func row(_ label: String, _ value: String, tint: Color = Palette.text) -> some View {
        HStack {
            Text(label).foregroundStyle(Palette.mute)
            Spacer()
            Text(value).monospacedDigit().foregroundStyle(tint)
        }
        .font(.body)
    }

    private func parse(_ s: String) -> Double? {
        let cleaned = s.filter { $0.isNumber || $0 == "." }
        return cleaned.isEmpty ? nil : Double(cleaned)
    }

    // MARK: 상태

    private func load() {
        restoreFromCell()
        hours = slot.hours
    }

    /// 원래 색으로 돌아오면 붙어 있던 전표도 돌아온다. 다른 색으로 가면 비운다.
    private func colorChanged() {
        if let cell, color == cell.color { restoreFromCell() } else { wonText = ""; tagText = ""; fromSalary = false }
        if color != .care { costText = ""; toColor = nil }
    }

    private func restoreFromCell() {
        wonText = cell?.won.map { String(Int($0)) } ?? ""
        tagText = cell?.tag ?? ""
        fromSalary = cell?.fromSalary ?? false
    }

    private func save() {
        guard let color else {                      // 안개 — 칸을 지운다
            if let cell { context.delete(cell) }
            dismiss()
            return
        }

        let target: TimeCell
        if let cell {
            if cell.color != color { cell.repaint(to: color) }
            target = cell
        } else {
            target = TimeCell(day: day, slot: slot, color: color)
            context.insert(target)
        }

        target.fromSalary = (color == .sold) && fromSalary
        // 월급 칸에는 금액도 태그도 붙이지 않는다. 붙이는 순간 배분과 이중 계상이 된다.
        if color.takesAmount { target.won = target.fromSalary ? nil : parse(wonText) }
        if color.takesTag {
            let t = tagText.trimmingCharacters(in: .whitespaces)
            target.tag = target.fromSalary ? nil : (t.isEmpty ? nil : t)
        }

        // 초록의 출금. 여기서 색칠판과 환전소가 물리적으로 이어진다.
        if color == .care, let cost = parse(costText), cost > 0, let to = toColor {
            context.insert(Exchange(kind: .withdrawal,
                                    date: day,
                                    title: "\(slot.label) 칸을 삼",
                                    won: cost,
                                    hours: hours,
                                    myRateAtTime: laborRate,
                                    slot: slot,
                                    fromColor: .care,
                                    toColor: to))
            target.repaint(to: to)
        }
        dismiss()
    }
}
