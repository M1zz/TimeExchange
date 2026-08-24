import SwiftUI
import UIKit

/// 데모의 팔레트를 옮기되, 라이트/다크 두 벌로 정의한다.
/// 색이 곧 계정과목이므로 색상값은 여기 한 곳에서만 정한다.
enum Palette {
    static let bg    = Color(light: 0xF2F4F7, dark: 0x101418)
    static let panel = Color(light: 0xFFFFFF, dark: 0x1A2026)
    static let line  = Color(light: 0xE1E6ED, dark: 0x2A323B)
    static let text  = Color(light: 0x121820, dark: 0xEDF1F4)
    static let mute  = Color(light: 0x69757F, dark: 0x8B97A3)

    /// 네 가지 계정과목. 두 모드에서 같은 색으로 읽혀야 하므로 명도만 살짝 조정한다.
    static let sold  = Color(light: 0xD8932A, dark: 0xE8A63C)
    static let seed  = Color(light: 0x4A7CE0, dark: 0x5B8DEF)
    static let joy   = Color(light: 0xDD5349, dark: 0xE8635B)
    static let care  = Color(light: 0x41A876, dark: 0x58B98A)

    /// 안개는 색이 아니라 색의 부재다. 칸의 기본 바탕이기도 하다.
    static let fog   = Color(light: 0xC7CEDA, dark: 0x3E4459)

    /// 계정과목 색 위에 얹는 글자. 배경이 두 모드에서 같으므로 이 값도 고정이다.
    static let ink   = Color(hex: 0x101418)
}

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB,
                  red:   Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >>  8) & 0xFF) / 255,
                  blue:  Double( hex        & 0xFF) / 255,
                  opacity: 1)
    }

    /// 시스템 외형을 따라가는 색.
    init(light: UInt32, dark: UInt32) {
        self.init(uiColor: UIColor { trait in
            UIColor(Color(hex: trait.userInterfaceStyle == .dark ? dark : light))
        })
    }
}

// MARK: - 키보드

extension View {
    /// 빈 곳을 누르면 키보드를 내린다. 숫자 키패드에는 완료 키가 없어서 이게 없으면 갇힌다.
    ///
    /// `simultaneousGesture`가 아니라 평범한 `onTapGesture`인 것이 중요하다.
    /// 동시 제스처로 걸면 글자 칸을 누를 때도 같이 발동해서 방금 올라온 키보드를 도로 내린다.
    /// 평범한 탭은 안쪽 컨트롤이 먼저 먹으므로 빈 곳을 눌렀을 때만 남는다.
    func dismissesKeyboardOnTap() -> some View {
        contentShape(Rectangle()).onTapGesture { Keyboard.dismiss() }
    }
}

enum Keyboard {
    static func dismiss() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                        to: nil, from: nil, for: nil)
    }
}

/// 숫자 키패드 위에 붙는 완료 버튼.
struct KeyboardDoneButton: ToolbarContent {
    var body: some ToolbarContent {
        ToolbarItemGroup(placement: .keyboard) {
            Spacer()
            Button("완료") { Keyboard.dismiss() }
        }
    }
}

// MARK: - 조각

/// 패널 한 장. 데모의 section에 해당한다.
struct Panel<Content: View>: View {
    var title: String?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let title {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .tracking(0.6)
                    .foregroundStyle(Palette.mute)
            }
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Palette.panel, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Palette.line))
    }
}

/// 문장 안에 박히는 색 점. 어느 계정과목 이야기인지 글자보다 먼저 알려준다.
struct ColorDot: View {
    let color: Color
    var body: some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(color)
            .frame(width: 12, height: 12)
    }
}
