import SwiftUI

/// 개념 페이지.
///
/// 색 이름만 보면 이 앱은 그냥 예쁜 시간표다. 왜 색마다 전표가 다르게 생겼는지,
/// 왜 네 숫자를 더하지 않는지를 모르면 며칠 쓰다 만다. 그 이유를 여기 모아 둔다.
struct ConceptView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                Palette.bg.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 14) {
                        premise
                        ForEach(TimeColor.allCases) { chapter(for: $0) }
                        fogChapter
                        returns
                        noSum
                        wage
                        exchange
                        repaint
                        notDoing
                    }
                    .padding(16)
                    .padding(.bottom, 60)
                }
            }
            .navigationTitle("개념")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Palette.bg, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
        .tint(Palette.text)
    }

    // MARK: 전제

    private var premise: some View {
        Panel(title: "전제") {
            VStack(alignment: .leading, spacing: 10) {
                Text("하루는 24시간이고, 늘릴 수 없습니다.")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(Palette.text)
                body("""
                그래서 시간은 예산이 아니라 자본입니다. 예산은 아껴 쓰면 남지만, 자본은 어디에 넣었는지를 \
                묻습니다. 돈 장부가 매출과 자산과 비용을 한 칸에 더하지 않듯, 시간 장부도 나눠야 합니다.
                """)
                body("""
                이 앱에서 그 구분은 색입니다. 색은 예쁘라고 있는 게 아니라 계정과목입니다. \
                색이 정해지면 그 칸에 무엇을 적을 수 있는지가 따라 정해집니다.
                """)
            }
        }
    }

    // MARK: 색

    private func chapter(for color: TimeColor) -> some View {
        Panel {
            VStack(alignment: .leading, spacing: 12) {
                headline(tint: color.tint, name: color.label, account: color.account)
                Divider().overlay(Palette.line)
                entry("무엇을 칠하나", meaning(color))
                entry("전표에 적는 것", ledger(color))
                entry("왜 이렇게 생겼나", reason(color))
                trap(caution(color))
            }
        }
    }

    private var fogChapter: some View {
        Panel {
            VStack(alignment: .leading, spacing: 12) {
                headline(tint: Palette.fog, name: "안개", account: "기록되지 않은 시간")
                Divider().overlay(Palette.line)
                entry("무엇을 칠하나", "아무것도 칠하지 않은 칸이 안개입니다. 기억이 안 나거나, 무슨 색인지 판단이 안 서는 시간입니다.")
                entry("전표에 적는 것", "없습니다. 안개에는 금액도 태그도 붙일 수 없습니다.")
                entry("왜 이렇게 생겼나", """
                안개에 돈을 붙이는 순간 이 앱은 죄책감 장치가 됩니다. \
                "이 두 시간에 얼마를 날렸다"는 문장은 아무것도 고치지 못하면서 기록을 그만두게 만듭니다. \
                그래서 안개는 개수만 셉니다.
                """)
                trap("""
                안개가 늘었다는 것은 더 칠하라는 뜻이 아닙니다. 그 시간에 무슨 일이 있었는지 물어보라는 신호입니다. \
                판단이 안 서면 안개로 두는 편이 아무 색이나 칠하는 것보다 정확합니다.
                """)
            }
        }
    }

    private func meaning(_ c: TimeColor) -> String {
        switch c {
        case .sold: "시간을 내주고 돈을 받은 시간. 출근, 외주, 강의, 멘토링."
        case .seed: "오늘은 0원이지만 나중에 값이 될 수 있는 시간. 글, 코드, 배움, 관계."
        case .joy:  "사는 이유에 해당하는 시간. 노는 것, 쉬는 것, 좋아하는 사람과 있는 것."
        case .care: "나와 주변이 굴러가게 하는 시간. 밥, 청소, 이동, 병원, 돌봄."
        }
    }

    private func ledger(_ c: TimeColor) -> String {
        switch c {
        case .sold: "입금액과 무엇을 팔았는지. 월급이면 금액 대신 «월급» 표시만 켭니다."
        case .seed: "태그만. 금액 칸이 아예 없습니다."
        case .joy:  "쓴 돈만. 이 시간의 가치는 적지 않습니다."
        case .care: "운영비. 그리고 이 칸을 돈으로 사는 거래."
        }
    }

    private func reason(_ c: TimeColor) -> String {
        switch c {
        case .sold: """
        노랑은 다섯 색 중 유일하게 돈이 관측되는 색입니다. 칸이 쌓이면 추정 시급이 실측 시급이 됩니다. \
        태그별로 칸당 단가가 갈리는 순간, 어느 노랑을 줄여야 하는지가 계산 없이 보입니다.
        """
        case .seed: """
        금액 칸이 없는 것은 실수가 아니라 원칙입니다. 심은 시간을 매일 평가하면 아직 값이 없는 일을 \
        그만두게 됩니다. 파랑은 오늘 0원인 것이 정상입니다. 수익이 실현된 날에만, 그 태그의 파란 칸 \
        전체로 소급해서 나눠 얹습니다.
        """
        case .joy: """
        빨강에는 원가만 붙입니다. 이 시간이 얼마짜리인지 계산하지 않습니다. \
        가격이 붙는 순간 누리는 능력이 죽기 때문입니다. 빨강은 투자의 목적이지 비용이 아닙니다.
        """
        case .care: """
        초록은 유일하게 돈으로 되살 수 있는 색입니다. 가사 대행과 택시가 그 거래입니다. \
        지불액을 넣고 무엇으로 바꿀지 고르면, 칸이 실제로 새 색이 되고 출금 기록이 하나 생깁니다. \
        여기서 색칠판과 환전소가 이어집니다.
        """
        }
    }

    private func caution(_ c: TimeColor) -> String {
        switch c {
        case .sold: "바쁠수록 노랑이 늘어납니다. 노랑이 많은 주가 좋은 주는 아닙니다. 노랑은 자본을 현금으로 바꾼 기록일 뿐입니다."
        case .seed: "파랑은 자기기만이 가장 쉬운 색입니다. 어느 자산에 심었는지 말할 수 없다면 그건 파랑이 아니라 안개입니다."
        case .joy:  "빨강이 한 칸도 없는 주가 이어지면, 배당 없는 투자만 하고 있는 것입니다."
        case .care: "초록을 모두 돈으로 사서 없애는 것이 목표가 아닙니다. 번 시급보다 비싸게 사면 다른 날에서 빌려온 것입니다."
        }
    }

    // MARK: 회수

    private var returns: some View {
        Panel(title: "심은 시간은 무엇으로 돌아오는가") {
            VStack(alignment: .leading, spacing: 10) {
                body("시간을 어딘가에 넣었으면 무언가로 나와야 합니다. 그 말은 맞습니다. 다만 나오는 형태가 하나가 아닙니다.")
                VStack(alignment: .leading, spacing: 10) {
                    twoRate("돈으로", "그 자산에서 수익이 실현됐다", "회수액을 적으면 그 태그의 파란 칸 전체로 소급 배분", Palette.sold)
                    twoRate("시간으로", "도구를 만들었더니 같은 일에 시간이 덜 든다", "앞으로 안 써도 되는 시간을 적는다", Palette.care)
                    twoRate("배당으로", "내가 만든 것 덕분에 즐거운 시간이 생겼다", "빨강 칸에 그 자산 이름을 잇는다. 세기만 한다", Palette.joy)
                }
                body("배당에 값을 매기지 않는 이유는 빨강에 값을 매기지 않는 이유와 같습니다. 내가 만든 것 덕분에 즐거웠던 시간에 가격을 붙이는 순간, 그 즐거움은 자산의 실적이 됩니다.")
                Divider().overlay(Palette.line)
                body("그리고 네 번째가 있습니다. 아무것도 돌아오지 않는 경우입니다.")
                body("그래서 «접음»이 회수의 한 종류로 들어가 있습니다. 접은 자산에 들어간 시간은 회수되지 않은 채로 확정됩니다. 이건 벌점이 아니라 정보입니다. 접은 것을 적지 않는 장부는 성공한 것만 기억하고, 그러면 남은 자산의 숫자도 못 믿게 됩니다.")
                trap("회수가 오기 전에는 시급을 계산하지 않습니다. 계산하면 반드시 0원이 나오고, 그 0원이 아직 값이 없는 일을 그만두게 만듭니다. 회수가 한 번이라도 실현된 뒤에만 시간당 얼마였는지 물어봅니다.")
            }
        }
    }

    // MARK: 합산

    private var noSum: some View {
        Panel(title: "왜 합산하지 않는가") {
            VStack(alignment: .leading, spacing: 10) {
                body("""
                주간 읽기는 다섯 줄이고 총점이 없습니다. 판 시간, 심은 시간, 누린 시간, 돌본 시간은 \
                단위가 다릅니다.
                """)
                body("""
                하나의 점수로 합치는 순간 올릴 대상이 생기고, 사람은 점수를 올리려고 삶을 바꿉니다. \
                시간 점수 90점을 만들려고 사는 사람은 없습니다. 재무제표가 매출과 자산과 비용을 \
                한 칸에 더하지 않는 것과 같은 이유로, 이 앱은 나란히만 둡니다.
                """)
                body("무엇을 줄이고 무엇을 늘릴지는 숫자가 아니라 당신이 정합니다. 앱은 재료만 놓습니다.")
            }
        }
    }

    // MARK: 월급

    private var wage: some View {
        Panel(title: "출근 시간을 전부 노랑으로 칠할 필요는 없다") {
            VStack(alignment: .leading, spacing: 10) {
                body("월급은 칸마다 입금되지 않습니다. 그래서 월급 칸에는 금액을 적지 않고, 그 달의 실수령액을 그 달의 월급 칸 전체로 나눕니다. 파랑의 회수와 같은 구조입니다.")
                body("여기서 중요한 것은, 출근한 여덟 시간을 모두 노랑으로 칠할 이유가 없다는 점입니다. 회사에서 배운 시간은 파랑이고, 회의와 잡무는 초록이고, 기억나지 않는 시간은 안개입니다. 노랑이 줄면 남은 노랑의 칸당 단가는 올라갑니다.")
                Divider().overlay(Palette.line)
                VStack(alignment: .leading, spacing: 10) {
                    twoRate("구속 시급", "월급 ÷ (근무 + 통근) 전체", "출금 판단에 쓰는 값", Palette.care)
                    twoRate("판 시간 시급", "월급 ÷ 실제로 노랑으로 칠한 시간", "관측만 하는 값", Palette.sold)
                }
                Divider().overlay(Palette.line)
                body("40시간 매여서 100만원을 받는데 실제로 판 시간이 20시간이면, 판 시간 시급은 5만원입니다. 밀도가 두 배라는 뜻이고, 그 자체로는 좋은 신호입니다.")
                body("하지만 이 5만원으로 출금을 판단하면 안 됩니다. 회사는 판 20시간이 아니라 매인 40시간에 돈을 줍니다. 5만원을 손에 쥐려면 여전히 네 시간을 앉아 있어야 합니다. 가사 대행에 5만원을 쓰고 «내 시급이 5만원이니 본전»이라고 계산하면, 실제로는 네 시간을 주고 한 시간을 산 것입니다.")
                trap("예외가 하나 있습니다. 한 시간을 더 팔면 돈이 더 들어오는 사람 — 프리랜서나 시간당 계약 — 에게는 판 시간 시급이 진짜 판단 기준입니다. 월급쟁이는 한 시간 더 앉아 있어도 추가 수입이 0이므로 그렇지 않습니다.")
            }
        }
    }

    private func twoRate(_ name: String, _ formula: String, _ use: String, _ tint: Color) -> some View {
        HStack(alignment: .top, spacing: 10) {
            RoundedRectangle(cornerRadius: 3).fill(tint).frame(width: 4).frame(maxHeight: .infinity)
            VStack(alignment: .leading, spacing: 2) {
                Text(name).font(.body.weight(.semibold)).foregroundStyle(Palette.text)
                Text(formula).font(.subheadline).foregroundStyle(Palette.mute)
                Text(use).font(.subheadline.weight(.semibold)).foregroundStyle(tint)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: 환율

    private var exchange: some View {
        Panel(title: "환율 — 초록을 돈으로 살 때만 쓴다") {
            VStack(alignment: .leading, spacing: 10) {
                body("""
                시급을 손으로 찍으면 사람은 자기 시간을 후하게 잡습니다. 그러면 모든 출금이 이득으로 \
                보이는 자기합리화 도구가 됩니다. 그래서 월급에서 도출합니다.
                """)
                formula("노동 환율 = 월 실수령액(세후) ÷ (월 근무시간 + 월 통근시간)")
                body("""
                분모에 통근을 넣는 것이 핵심입니다. 급여에 잡히지 않지만 회사 때문에 쓰는 시간이므로 \
                판 시간이 맞습니다. 통근을 빼면 시급이 20% 가까이 부풀려집니다.
                """)
                Divider().overlay(Palette.line)
                VStack(alignment: .leading, spacing: 6) {
                    ratioRow("번 ÷ 산 > 1", "내 시급보다 싸게 샀다 — 시간이 실제로 늘어남", Palette.care)
                    ratioRow("번 ÷ 산 = 1", "시간이 이동만 함", Palette.mute)
                    ratioRow("번 ÷ 산 < 1", "비싸게 샀다 — 다른 날에서 빌려옴", Palette.joy)
                }
                body("순증 = 돌려받은 시간 − 그 돈을 벌려고 쓴 시간. 이 계산에는 노동 환율만 씁니다. 자산 환율은 성격이 달라 섞지 않습니다.")
            }
        }
    }

    // MARK: 리셋

    private var repaint: some View {
        Panel(title: "색을 바꾸면 전표가 지워진다") {
            VStack(alignment: .leading, spacing: 10) {
                body("""
                계정과목이 바뀌었는데 전표를 그대로 이월하는 것은 회계상 틀립니다. \
                노랑의 입금액이 파랑으로 따라가면 그 순간 장부가 거짓말을 시작합니다.
                """)
                body("""
                그래서 색이 바뀌면 전표도 함께 지워집니다. 실수로 지우지 않도록, 물감으로 덮을 때는 \
                전표가 붙은 칸을 건너뛰고 손을 뗀 뒤에 물어봅니다. 전표 시트에서 색을 바꿀 때는 \
                저장을 눌러야 실제로 지워지고, 원래 색으로 되돌리면 전표도 돌아옵니다.
                """)
            }
        }
    }

    // MARK: 하지 않는 것

    private var notDoing: some View {
        Panel(title: "이 앱이 하지 않는 것") {
            VStack(alignment: .leading, spacing: 8) {
                dont("점수를 매기지 않습니다.", "합산할 수 없는 것을 합산하지 않기 때문입니다.")
                dont("목표를 정해 주지 않습니다.", "파랑을 몇 칸 채우라는 말은 이 앱이 할 수 있는 말이 아닙니다.")
                dont("안개에 금액을 붙이지 않습니다.", "기록을 그만두게 만드는 가장 빠른 길이기 때문입니다.")
                dont("빨강의 가치를 계산하지 않습니다.", "가격이 붙으면 누리는 능력이 죽기 때문입니다.")
            }
        }
    }

    // MARK: 조각

    private func headline(tint: Color, name: String, account: String) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8)
                .fill(tint)
                .frame(width: 42, height: 42)
            VStack(alignment: .leading, spacing: 2) {
                Text(name).font(.title2.weight(.semibold)).foregroundStyle(Palette.text)
                Text(account).font(.callout).foregroundStyle(Palette.mute)
            }
        }
    }

    private func entry(_ label: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Palette.mute)
            Text(text)
                .font(.body)
                .foregroundStyle(Palette.text)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func trap(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle")
                .font(.subheadline)
                .foregroundStyle(Palette.sold)
                .padding(.top, 2)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(Palette.mute)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Palette.bg, in: RoundedRectangle(cornerRadius: 10))
    }

    private func body(_ text: String) -> some View {
        Text(text)
            .font(.body)
            .foregroundStyle(Palette.text)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func formula(_ text: String) -> some View {
        Text(text)
            .font(.callout.monospaced())
            .foregroundStyle(Palette.text)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .background(Palette.bg, in: RoundedRectangle(cornerRadius: 10))
    }

    private func ratioRow(_ formula: String, _ meaning: String, _ tint: Color) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(formula)
                .font(.callout.monospaced().weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 128, alignment: .leading)
            Text(meaning)
                .font(.subheadline)
                .foregroundStyle(Palette.mute)
        }
    }

    private func dont(_ what: String, _ why: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "minus")
                .font(.footnote.weight(.bold))
                .foregroundStyle(Palette.mute)
                .padding(.top, 4)
            VStack(alignment: .leading, spacing: 2) {
                Text(what).font(.body).foregroundStyle(Palette.text)
                Text(why).font(.subheadline).foregroundStyle(Palette.mute)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
