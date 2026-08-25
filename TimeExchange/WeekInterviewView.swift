import SwiftUI
import SwiftData

/// 한 주를 질문으로 칠한다.
///
/// 하루를 전부 인지하려 들면 기록은 곧 노동이 되고, 그러면 아무도 쓰지 않는다.
/// 그래서 기본값은 빈 주이고, 질문에 기억나는 것만 답한다. 나머지는 안개로 남는다.
/// 사람은 시간 블록이 아니라 사건으로 회상하므로, 질문도 "화요일 오전에 뭘 했나"가 아니라
/// "무엇을 팔았나"로 묻는다.
struct WeekInterviewView: View {
    let monday: Date
    let throughIndex: Int

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \TimeCell.day) private var allCells: [TimeCell]

    @State private var step = 0
    /// 전표가 붙어 있어 손대지 않은 칸. 마지막에 한 번만 알린다.
    @State private var untouched = 0

    private let calendar = Calendar.current

    // MARK: 질문

    private struct Step {
        let color: TimeColor
        let question: String
        let hint: String
    }

    /// 회상이 잘 되는 순서로 묻는다. 일정이 있는 노랑이 제일 선명하고, 사건인 빨강이 그 다음이다.
    /// 루틴인 초록이 제일 흐릿하므로 맨 뒤에 둔다.
    private let steps: [Step] = [
        Step(color: .sold,
             question: "이번 주에 무엇을 팔았나요?",
             hint: "시간을 내주고 돈을 받은 시간입니다. 출근, 외주, 강의, 멘토링."),
        Step(color: .joy,
             question: "누린 시간이 있었나요?",
             hint: "노는 것, 쉬는 것, 좋아하는 사람과 있는 것. 한 칸도 없어도 그건 그것대로 읽힙니다."),
        Step(color: .seed,
             question: "무엇에 심었나요?",
             hint: "오늘은 0원이지만 나중에 값이 될 수 있는 시간입니다. 글, 코드, 배움, 관계."),
        Step(color: .care,
             question: "나와 주변을 돌본 시간은요?",
             hint: "밥, 청소, 이동, 병원, 돌봄. 제일 기억이 안 나는 색이니 기억나는 것만.")
    ]

    private var isSummary: Bool { step >= steps.count }
    private var current: Step? { isSummary ? nil : steps[step] }

    private var days: [Date] { Week.days(from: monday, calendar: calendar) }

    private var lookup: [String: TimeCell] {
        Dictionary(allCells.map { (key($0.day, $0.slot), $0) }, uniquingKeysWith: { a, _ in a })
    }

    // MARK: 본문

    var body: some View {
        NavigationStack {
            ZStack {
                Palette.bg.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        progress
                        if let current {
                            questionBlock(current)
                        } else {
                            summary
                        }
                    }
                    .padding(16)
                    .padding(.bottom, 100)
                }
                VStack {
                    Spacer()
                    footer
                }
            }
            .navigationTitle("한 주 묻기")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Palette.bg, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기") { dismiss() }
                }
            }
        }
        .tint(Palette.text)
    }

    private var progress: some View {
        HStack(spacing: 6) {
            ForEach(0..<steps.count, id: \.self) { i in
                Capsule()
                    .fill(i <= step ? (i < steps.count ? steps[min(i, steps.count - 1)].color.tint : Palette.text) : Palette.line)
                    .frame(height: 4)
            }
        }
    }

    // MARK: 질문 한 장

    private func questionBlock(_ s: Step) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    ColorDot(color: s.color.tint)
                    Text(s.color.label)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(s.color.tint)
                }
                Text(s.question)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(Palette.text)
                Text(s.hint)
                    .font(.body)
                    .foregroundStyle(Palette.mute)
            }

            chunks(for: s.color)
            grid(for: s.color)

            Text("문질러 칠하세요. 기억나지 않으면 그냥 넘어가면 됩니다. 안 칠한 칸은 안개로 남습니다.")
                .font(.subheadline)
                .foregroundStyle(Palette.mute)
        }
    }

    // MARK: 빠른 덩어리

    private struct Chunk: Identifiable {
        let name: String
        let dayIndexes: [Int]
        let slots: [Slot]
        var id: String { name }
    }

    private let chunkList: [Chunk] = [
        Chunk(name: "평일 낮",   dayIndexes: [0, 1, 2, 3, 4], slots: [.forenoon, .lunch, .afternoon]),
        Chunk(name: "평일 저녁", dayIndexes: [0, 1, 2, 3, 4], slots: [.lateAfternoon, .evening]),
        Chunk(name: "평일 아침", dayIndexes: [0, 1, 2, 3, 4], slots: [.dawn, .morning]),
        Chunk(name: "주말 낮",   dayIndexes: [5, 6],          slots: [.forenoon, .lunch, .afternoon]),
        Chunk(name: "주말 저녁", dayIndexes: [5, 6],          slots: [.lateAfternoon, .evening])
    ]

    private func chunks(for color: TimeColor) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(chunkList) { chunk in
                    let filled = isFilled(chunk, with: color)
                    Button {
                        toggle(chunk, color: color, currentlyFilled: filled)
                    } label: {
                        Text(chunk.name)
                            .font(.subheadline.weight(.medium))
                            .padding(.horizontal, 12).padding(.vertical, 8)
                            .background(filled ? color.tint : Palette.panel, in: Capsule())
                            .foregroundStyle(filled ? Palette.ink : Palette.text)
                            .overlay(Capsule().strokeBorder(filled ? .clear : Palette.line))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 2)
        }
    }

    /// 그 덩어리의 칠할 수 있는 칸이 이미 전부 이 색인가.
    private func isFilled(_ chunk: Chunk, with color: TimeColor) -> Bool {
        let spots = paintable(chunk)
        guard !spots.isEmpty else { return false }
        return spots.allSatisfy { lookup[key(days[$0.dayIndex], $0.slot)]?.color == color }
    }

    private func paintable(_ chunk: Chunk) -> [CellSpot] {
        chunk.dayIndexes.filter { $0 <= throughIndex }
            .flatMap { day in chunk.slots.map { CellSpot(dayIndex: day, slot: $0) } }
    }

    private func toggle(_ chunk: Chunk, color: TimeColor, currentlyFilled: Bool) {
        for spot in paintable(chunk) {
            currentlyFilled ? erase(spot) : paint(spot, color: color)
        }
    }

    // MARK: 격자

    private let labelW: CGFloat = 44
    private let gap: CGFloat = 6
    private let headerH: CGFloat = 20
    private let cellH: CGFloat = 34

    private var gridHeight: CGFloat {
        headerH + gap + CGFloat(Slot.allCases.count) * cellH + CGFloat(Slot.allCases.count - 1) * gap
    }

    private func grid(for color: TimeColor) -> some View {
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
                                cellView(col: col, slot: slot, brush: color)
                                    .frame(width: cellW, height: cellH)
                            }
                        }
                    }
                }
                .contentShape(Rectangle())
                .modifier(PaintDrag(active: true) { location in
                    guard let spot = hit(location, cellW: cellW) else { return }
                    paint(spot, color: color)
                } onEnd: {})
            }
            .frame(height: gridHeight)
        }
    }

    private func cellView(col: Int, slot: Slot, brush: TimeColor) -> some View {
        let future = col > throughIndex
        let cell = lookup[key(days[col], slot)]
        let mine = cell?.color == brush
        return Button {
            let spot = CellSpot(dayIndex: col, slot: slot)
            mine ? erase(spot) : paint(spot, color: brush)
        } label: {
            RoundedRectangle(cornerRadius: 6)
                .fill(cell?.color.tint ?? Palette.fog)
                // 지금 묻는 색이 아닌 칸은 뒤로 물러난다. 앞 질문의 답이라 참고만 하면 된다.
                .opacity(cell == nil || mine ? 1 : 0.45)
                .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(.primary.opacity(0.07)))
        }
        .buttonStyle(.plain)
        .opacity(future ? 0.25 : 1)
        .disabled(future)
        .accessibilityLabel("\(Week.dayLabels[col])요일 \(slot.label)")
        .accessibilityValue(cell?.color.label ?? "안개")
    }

    private func hit(_ p: CGPoint, cellW: CGFloat) -> CellSpot? {
        let x = p.x - labelW - gap
        let y = p.y - headerH - gap
        guard x >= 0, y >= 0 else { return nil }
        let col = Int(x / (cellW + gap))
        let row = Int(y / (cellH + gap))
        guard (0..<7).contains(col), (0..<Slot.allCases.count).contains(row), col <= throughIndex else { return nil }
        return CellSpot(dayIndex: col, slot: Slot(rawValue: row) ?? .dawn)
    }

    // MARK: 칠하기

    private func key(_ day: Date, _ slot: Slot) -> String {
        "\(Int(calendar.startOfDay(for: day).timeIntervalSince1970))#\(slot.rawValue)"
    }

    private func paint(_ spot: CellSpot, color: TimeColor) {
        guard spot.dayIndex <= throughIndex else { return }
        let day = calendar.startOfDay(for: days[spot.dayIndex])
        if let existing = lookup[key(day, spot.slot)] {
            if existing.color == color { return }
            // 전표가 붙은 칸은 이 흐름에서 건드리지 않는다. 색을 바꾸면 전표가 지워지는데,
            // 빠르게 넘기는 중에 그런 일이 벌어지면 안 된다.
            if existing.hasLedger { untouched += 1; return }
            existing.repaint(to: color)
        } else {
            context.insert(TimeCell(day: day, slot: spot.slot, color: color))
        }
    }

    private func erase(_ spot: CellSpot) {
        let day = calendar.startOfDay(for: days[spot.dayIndex])
        guard let existing = lookup[key(day, spot.slot)] else { return }
        if existing.hasLedger { untouched += 1; return }
        context.delete(existing)
    }

    // MARK: 마무리

    private var weekCells: [TimeCell] {
        let set = Set(days.prefix(max(0, throughIndex + 1)).map { calendar.startOfDay(for: $0) })
        return allCells.filter { set.contains(calendar.startOfDay(for: $0.day)) }
    }

    private var summary: some View {
        let painted = weekCells.count
        let past = max(0, throughIndex + 1) * Slot.allCases.count
        let fog = max(0, past - painted)
        return VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("여기까지입니다.")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(Palette.text)
                Text("지나간 \(past)칸 중 \(painted)칸을 칠했습니다.")
                    .font(.body)
                    .monospacedDigit()
                    .foregroundStyle(Palette.mute)
            }

            Panel {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(TimeColor.allCases) { c in
                        let n = weekCells.filter { $0.color == c }.count
                        HStack(spacing: 10) {
                            ColorDot(color: c.tint)
                            Text(c.label).foregroundStyle(Palette.text)
                            Spacer()
                            Text("\(n)칸").monospacedDigit().foregroundStyle(Palette.mute)
                        }
                        .font(.body)
                    }
                    Divider().overlay(Palette.line)
                    HStack(spacing: 10) {
                        ColorDot(color: Palette.fog)
                        Text("안개").foregroundStyle(Palette.text)
                        Spacer()
                        Text("\(fog)칸").monospacedDigit().foregroundStyle(Palette.mute)
                    }
                    .font(.body)
                }
            }

            Panel {
                VStack(alignment: .leading, spacing: 10) {
                    Text("안개 \(fog)칸은 실패가 아닙니다.")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Palette.text)
                    Text("기억나지 않는 시간에 색을 지어내면 그 순간부터 장부가 아니라 소설이 됩니다. 하루를 전부 인지하는 것은 이 앱의 목표가 아닙니다.")
                        .font(.body)
                        .foregroundStyle(Palette.mute)
                    Text("돈이 붙는 칸은 색칠판에서 눌러 전표를 붙이면 됩니다. 안 붙여도 색은 남습니다.")
                        .font(.subheadline)
                        .foregroundStyle(Palette.mute)
                }
            }

            if untouched > 0 {
                Text("전표가 붙어 있던 \(untouched)칸은 그대로 두었습니다. 색을 바꾸려면 색칠판에서 하세요.")
                    .font(.subheadline)
                    .foregroundStyle(Palette.sold)
            }
        }
    }

    // MARK: 아래 버튼

    private var footer: some View {
        HStack(spacing: 10) {
            if step > 0 {
                Button("뒤로") { step -= 1 }
                    .font(.body)
                    .padding(.vertical, 14).padding(.horizontal, 20)
                    .background(Palette.panel, in: RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Palette.line))
                    .foregroundStyle(Palette.text)
            }
            Button(isSummary ? "마치기" : (step == steps.count - 1 ? "다 됐습니다" : "다음")) {
                if isSummary { dismiss() } else { step += 1 }
            }
            .font(.body.weight(.semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Palette.text, in: RoundedRectangle(cornerRadius: 12))
            .foregroundStyle(Palette.bg)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
        .padding(.top, 10)
        .background(Palette.bg.opacity(0.96))
    }
}
