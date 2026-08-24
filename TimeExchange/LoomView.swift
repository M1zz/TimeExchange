import SwiftUI
import SwiftData

/// 칸을 가리키는 좌표. 요일 인덱스와 시간대.
struct CellSpot: Identifiable, Hashable {
    let dayIndex: Int
    let slot: Slot
    var id: String { "\(dayIndex)-\(slot.rawValue)" }
}

/// 지금 손에 들고 있는 것. 모드 스위치 대신 이것 하나로 동작이 갈린다.
enum Tool: Hashable {
    /// 아무것도 안 들었다. 칸을 누르면 전표가 열린다. 기본값.
    case ledger
    case color(TimeColor)
    /// 지우개. 칠한 것을 안개로 되돌린다.
    case fog

    var isPaint: Bool { self != .ledger }

    var tint: Color {
        switch self {
        case .ledger:          Palette.panel
        case .color(let c):    c.tint
        case .fog:             Palette.fog
        }
    }

    var label: String {
        switch self {
        case .ledger:          "전표"
        case .color(let c):    c.label
        case .fog:             "안개"
        }
    }

    /// 칠할 색. 안개는 색이 아니라 지움이므로 nil이다.
    var paintColor: TimeColor? {
        if case .color(let c) = self { return c }
        return nil
    }

    static let all: [Tool] = [.ledger] + TimeColor.allCases.map { .color($0) } + [.fog]
}

// MARK: - 색칠판

/// 한 주의 격자.
///
/// 물감을 들지 않았으면 칸을 누를 때 전표가 열린다. 물감을 들면 문질러 칠한다.
/// 손에 든 것이 곧 모드이므로 따로 모드를 고르는 자리는 없다.
struct LoomView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \TimeCell.day) private var allCells: [TimeCell]

    @AppStorage("monthlyNetPay") private var monthlyNetPay = RateDefaults.monthlyNetPay
    @AppStorage("weeklyWorkHours") private var weeklyWorkHours = RateDefaults.weeklyWorkHours
    @AppStorage("workDaysPerMonth") private var workDaysPerMonth = RateDefaults.workDaysPerMonth
    @AppStorage("dailyCommuteHours") private var dailyCommuteHours = RateDefaults.dailyCommuteHours
    @AppStorage("totalAssets") private var totalAssets = RateDefaults.totalAssets
    @AppStorage("annualReturnPercent") private var annualReturnPercent = RateDefaults.annualReturnPercent

    @Environment(BoardState.self) private var board
    @State private var tool: Tool = .ledger
    @State private var target: CellSpot?

    /// 전표가 붙어 있어 칠하기가 건너뛴 칸들. 손을 떼면 한꺼번에 물어본다.
    @State private var skipped: [CellSpot] = []
    @State private var pendingColor: TimeColor?
    @State private var askRepaint = false

    private let calendar = Calendar.current

    private var days: [Date] { Week.days(from: board.monday, calendar: calendar) }

    /// 집계에 넣을 마지막 요일. 아직 오지 않은 칸은 칠할 수도, 읽을 수도 없다.
    private var throughIndex: Int {
        let today = calendar.startOfDay(for: .now)
        if let i = days.firstIndex(where: { calendar.isDate($0, inSameDayAs: today) }) { return i }
        return board.monday < today ? 6 : -1
    }

    private var lookup: [String: TimeCell] {
        Dictionary(allCells.map { (key($0.day, $0.slot), $0) }, uniquingKeysWith: { a, _ in a })
    }

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
            ZStack {
                Palette.bg.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 14) {
                        header
                        loomGrid
                        palette
                        legend
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 70)
                }
            }
            .navigationTitle("시간의 색")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Palette.bg, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
        .tint(Palette.text)
        .sheet(item: $target) { spot in
            LedgerSheet(day: calendar.startOfDay(for: days[spot.dayIndex]),
                        slot: spot.slot,
                        cell: lookup[key(days[spot.dayIndex], spot.slot)],
                        seedTags: seedTagSuggestions,
                        laborRate: profile.laborRate)
        }
        .alert("전표가 붙은 칸입니다", isPresented: $askRepaint) {
            Button("취소", role: .cancel) { skipped = [] }
            Button("전표 지우고 칠하기", role: .destructive) { forceRepaint() }
        } message: {
            Text("\(skipped.count)칸은 칠해지지 않았습니다.\n색이 바뀌면 계정과목이 바뀝니다. 노랑의 입금액을 파랑으로 이월하는 것은 회계상 틀리므로, 색을 바꾸면 전표는 함께 지워집니다.")
        }
    }

    // MARK: 주 이동

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Button { shiftWeek(-1) } label: { Image(systemName: "chevron.left") }
                Text(board.weekTitle(calendar: calendar))
                    .font(.headline)
                    .foregroundStyle(Palette.text)
                    .frame(maxWidth: .infinity)
                Button { shiftWeek(1) } label: { Image(systemName: "chevron.right") }
                    .disabled(board.monday >= Week.monday(of: .now, calendar: calendar))
            }
            .foregroundStyle(Palette.mute)

            Text(tool.isPaint
                 ? "\(tool.label) 물감을 들었습니다. 칸을 문질러 칠하세요."
                 : "칸을 누르면 전표가 열립니다. 아래에서 물감을 집으면 문질러 칠할 수 있습니다.")
                .font(.body)
                .foregroundStyle(Palette.mute)
        }
        .padding(.top, 8)
    }

    private func shiftWeek(_ delta: Int) {
        guard let next = calendar.date(byAdding: .day, value: delta * 7, to: board.monday) else { return }
        board.monday = next
    }

    // MARK: 그리드

    private let labelW: CGFloat = 44
    private let gap: CGFloat = 6
    private let headerH: CGFloat = 20
    private let cellH: CGFloat = 38

    private var boardHeight: CGFloat {
        headerH + gap + CGFloat(Slot.allCases.count) * cellH + CGFloat(Slot.allCases.count - 1) * gap
    }

    private var loomGrid: some View {
        Panel {
            GeometryReader { geo in
                let cellW = max(1, (geo.size.width - labelW - 7 * gap) / 7)
                VStack(spacing: gap) {
                    HStack(spacing: gap) {
                        Color.clear.frame(width: labelW)
                        ForEach(Array(Week.dayLabels.enumerated()), id: \.offset) { i, label in
                            Text(label)
                                .font(.subheadline)
                                .foregroundStyle(i == throughIndex ? Palette.text : Palette.mute)
                                .fontWeight(i == throughIndex ? .bold : .regular)
                                .frame(width: cellW)
                        }
                    }
                    .frame(height: headerH)

                    ForEach(Slot.allCases) { slot in
                        HStack(spacing: gap) {
                            Text(slot.label)
                                .font(.footnote)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                                .foregroundStyle(Palette.mute)
                                .frame(width: labelW, alignment: .trailing)
                            ForEach(0..<7, id: \.self) { col in
                                cellView(col: col, slot: slot)
                                    .frame(width: cellW, height: cellH)
                            }
                        }
                    }
                }
                .contentShape(Rectangle())
                // 물감을 들었을 때만 드래그를 가로챈다. 전표일 때는 스크롤을 방해하지 않아야 한다.
                .modifier(PaintDrag(active: tool.isPaint) { location in
                    guard let spot = hit(location, cellW: cellW) else { return }
                    paint(spot)
                } onEnd: {
                    if !skipped.isEmpty { askRepaint = true }
                })
            }
            .frame(height: boardHeight)
        }
    }

    private func cellView(col: Int, slot: Slot) -> some View {
        let future = col > throughIndex
        let cell = lookup[key(days[col], slot)]
        return Button {
            if tool.isPaint {
                paint(CellSpot(dayIndex: col, slot: slot))
                if !skipped.isEmpty { askRepaint = true }
            } else {
                target = CellSpot(dayIndex: col, slot: slot)
            }
        } label: {
            RoundedRectangle(cornerRadius: 7)
                .fill(cell?.color.tint ?? Palette.fog)
                .overlay(alignment: .topTrailing) {
                    if cell?.hasLedger == true {
                        Circle().fill(Palette.ink.opacity(0.55)).frame(width: 6, height: 6).padding(3)
                    }
                }
                .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(.primary.opacity(0.07)))
        }
        .buttonStyle(.plain)
        .opacity(future ? 0.25 : 1)
        .disabled(future)
        .accessibilityLabel("\(Week.dayLabels[col])요일 \(slot.label)")
        .accessibilityValue(cell?.color.label ?? "안개")
    }

    /// 좌표를 칸으로 되돌린다. 그리드가 균등하므로 프레임을 모으지 않고 계산으로 찾는다.
    private func hit(_ p: CGPoint, cellW: CGFloat) -> CellSpot? {
        let x = p.x - labelW - gap
        let y = p.y - headerH - gap
        guard x >= 0, y >= 0 else { return nil }
        let col = Int(x / (cellW + gap))
        let row = Int(y / (cellH + gap))
        guard (0..<7).contains(col), (0..<Slot.allCases.count).contains(row), col <= throughIndex else { return nil }
        return CellSpot(dayIndex: col, slot: Slot(rawValue: row) ?? .dawn)
    }

    private func key(_ day: Date, _ slot: Slot) -> String {
        "\(Int(calendar.startOfDay(for: day).timeIntervalSince1970))#\(slot.rawValue)"
    }

    // MARK: 칠하기

    private func paint(_ spot: CellSpot) {
        guard spot.dayIndex <= throughIndex else { return }
        let day = calendar.startOfDay(for: days[spot.dayIndex])
        let existing = lookup[key(day, spot.slot)]

        guard let color = tool.paintColor else {        // 안개로 지우기
            guard let existing else { return }
            if existing.hasLedger { note(spot); return }
            context.delete(existing)
            return
        }
        if existing?.color == color { return }
        if let existing {
            if existing.hasLedger { note(spot); return }
            existing.repaint(to: color)
        } else {
            context.insert(TimeCell(day: day, slot: spot.slot, color: color))
        }
    }

    /// 데모에서는 전표가 조용히 사라진다. 여기서는 일단 건너뛰고 손을 뗀 뒤에 물어본다.
    private func note(_ spot: CellSpot) {
        pendingColor = tool.paintColor
        if !skipped.contains(spot) { skipped.append(spot) }
    }

    private func forceRepaint() {
        for spot in skipped {
            let day = calendar.startOfDay(for: days[spot.dayIndex])
            guard let cell = lookup[key(day, spot.slot)] else { continue }
            if let color = pendingColor { cell.repaint(to: color) } else { context.delete(cell) }
        }
        skipped = []
    }

    // MARK: 물감

    private var palette: some View {
        Panel {
            HStack(spacing: 2) {
                ForEach(Tool.all, id: \.self) { t in
                    tube(t)
                }
            }
        }
    }

    private func tube(_ t: Tool) -> some View {
        let on = tool == t
        return Button {
            // 들고 있던 물감을 다시 누르면 내려놓는다. 그러면 다시 전표다.
            tool = on ? .ledger : t
        } label: {
            VStack(spacing: 5) {
                ZStack {
                    Circle()
                        .fill(t.tint)
                        .overlay(Circle().strokeBorder(t == .ledger ? Palette.line : .clear))
                    if t == .ledger {
                        Image(systemName: "doc.text")
                            .font(.system(size: 13))
                            .foregroundStyle(on ? Palette.text : Palette.mute)
                    }
                }
                .frame(width: 30, height: 30)
                .overlay(Circle().strokeBorder(on ? Palette.text : .clear, lineWidth: 2))
                .scaleEffect(on ? 1.1 : 1)

                Text(t.label)
                    .font(.footnote)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .foregroundStyle(on ? Palette.text : Palette.mute)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .animation(.easeOut(duration: 0.12), value: on)
        .accessibilityLabel(t == .ledger ? "전표. 칸을 누르면 전표가 열립니다" : "\(t.label) 물감")
        .accessibilityAddTraits(on ? [.isSelected] : [])
    }

    // MARK: 범례

    private var legend: some View {
        Panel(title: "색이 곧 계정과목입니다") {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(TimeColor.allCases) { c in
                    HStack(spacing: 8) {
                        ColorDot(color: c.tint)
                        Text(c.label).foregroundStyle(Palette.text)
                        Text(c.account).foregroundStyle(Palette.mute)
                    }
                    .font(.body)
                }
                HStack(spacing: 8) {
                    ColorDot(color: Palette.fog)
                    Text("안개").foregroundStyle(Palette.text)
                    Text("기억이 안 나면 누수, 판단이 안 서면 미결").foregroundStyle(Palette.mute)
                }
                .font(.body)
                Text("점이 찍힌 칸에는 전표가 붙어 있습니다. 색마다 전표가 왜 다르게 생겼는지는 «개념» 탭에 있습니다.")
                    .font(.subheadline)
                    .foregroundStyle(Palette.mute)
                    .padding(.top, 2)
            }
        }
    }

    private var seedTagSuggestions: [String] {
        Array(Set(allCells.compactMap { $0.color == .seed ? $0.tag : nil }.filter { !$0.isEmpty })).sorted()
    }
}

/// 물감을 들었을 때만 드래그를 가로챈다.
private struct PaintDrag: ViewModifier {
    let active: Bool
    let onMove: (CGPoint) -> Void
    let onEnd: () -> Void

    func body(content: Content) -> some View {
        if active {
            content.highPriorityGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { onMove($0.location) }
                    .onEnded { _ in onEnd() }
            )
        } else {
            content
        }
    }
}
