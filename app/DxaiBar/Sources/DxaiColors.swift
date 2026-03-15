import SwiftUI

/// DxaiBar 적응형 컬러 팔레트
/// 다크/라이트 모드에 따라 최적화된 색상과 opacity를 반환한다.
struct DxaiColors {
    let scheme: ColorScheme
    private var isDark: Bool { scheme == .dark }

    // MARK: - Accent (yellow → amber in light)

    /// 코인, 랭킹, Gold 티어 등 주 강조색
    var accent: Color {
        isDark ? .yellow : Color(red: 0.72, green: 0.53, blue: 0.04)
    }

    /// 액센트 텍스트 (약간 어두운 버전)
    var accentText: Color {
        isDark ? .yellow.opacity(0.9) : Color(red: 0.63, green: 0.46, blue: 0.04)
    }

    /// 경고 색상 (health, battery 등)
    var warning: Color {
        isDark ? .yellow : Color(red: 0.80, green: 0.53, blue: 0.0)
    }

    // MARK: - Background Opacity

    /// 가장 연한 배경 (요약 섹션, 컨테이너)
    var bgSubtle: CGFloat { isDark ? 0.06 : 0.08 }

    /// 태그/칩 배경
    var bgChip: CGFloat { isDark ? 0.10 : 0.15 }

    /// 카드/배지 배경
    var bgCard: CGFloat { isDark ? 0.12 : 0.18 }

    /// 호버/활성 상태 배경
    var bgHover: CGFloat { isDark ? 0.08 : 0.12 }

    /// 프로그레스 바 트랙 (비활성)
    var bgTrack: CGFloat { isDark ? 0.15 : 0.20 }

    // MARK: - Text Opacity (.secondary 기반)

    /// 최저 가시 텍스트 (구분점, 미래 티어)
    var textFaint: CGFloat { isDark ? 0.3 : 0.45 }

    /// 연한 텍스트 (PID, 시간, 설정 설명)
    var textMuted: CGFloat { isDark ? 0.4 : 0.55 }

    /// 서브텍스트 (바 수치, 자막)
    var textSub: CGFloat { isDark ? 0.5 : 0.65 }

    /// 보조 텍스트 (설명, 부가정보)
    var textDim: CGFloat { isDark ? 0.6 : 0.75 }

    /// 캡션/칩 라벨
    var textCaption: CGFloat { isDark ? 0.7 : 0.85 }

    // MARK: - Brand

    var claude: Color { Color(red: 0.85, green: 0.47, blue: 0.34) }
    var codex: Color { Color(red: 0.06, green: 0.64, blue: 0.50) }

    // MARK: - Vanguard Tier

    func tierColor(_ tier: DxaiViewModel.VanguardLevel.Tier) -> Color {
        switch tier {
        case .bronze:      return .orange
        case .silver:      return .gray
        case .gold:        return accent
        case .platinum:    return .teal
        case .diamond:     return .cyan
        case .master:      return .purple
        case .grandmaster: return .red
        case .challenger:
            return isDark
                ? Color(red: 1.0, green: 0.84, blue: 0.0)
                : Color(red: 0.75, green: 0.58, blue: 0.0)
        }
    }

    func levelColor(_ level: DxaiViewModel.VanguardLevel?) -> Color {
        guard let level else { return .purple }
        return tierColor(level.tier)
    }
}
