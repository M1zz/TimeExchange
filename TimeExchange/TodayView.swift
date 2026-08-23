import SwiftUI
import SwiftData

struct TodayView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Exchange.date, order: .reverse) private var all: [Exchange]

    @AppStorage("monthlyNetPay") private var monthlyNetPay = RateDefaults.monthlyNetPay
    @AppStorage("weeklyWorkHours") private var weeklyWorkHours = RateDefaults.weeklyWorkHours
    @AppStorage("workDaysPerMonth") private var workDaysPerMonth = RateDefaults.workDaysPerMonth
    @AppStorage("dailyCommuteHours") private var dailyCommuteHours = RateDefaults.dailyCommuteHours
    @AppStorage("totalAssets") private var totalAssets = RateDefaults.totalAssets
    @AppStorage("annualReturnPercent") private var annualReturnPercent = RateDefaults.annualReturnPercent

    @State private var sheetKind: ExchangeKind?

    private var profile: RateProfile {
        RateProfile(monthlyNetPay: monthlyNetPay,
                    weeklyWorkHours: weeklyWorkHours,
                    workDaysPerMonth: workDaysPerMonth,
                    dailyCommuteHours: dailyCommuteHours,
                    totalAssets: totalAssets,
                    annualReturnPercent: annualReturnPercent)
    }

    /// 앱의 핵심 환율. 거래 계산에는 노동 환율만 쓴다.
    private var myRate: Double { profile.laborRate }

    private var today: DaySummary {
        let cal = Calendar.current
        return DaySummary(date: .now, exchanges: all.filter { cal.isDateInToday($0.date) })
    }

    /// 전체 잔고 (원). 입금 누계 − 출금 누계.
    private var balanceWon: Double {
        all.reduce(0) { $0 + ($1.kind == .deposit ? $1.won : -$1.won) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    RateBoard(profile: profile)
                    BalanceCard(balanceWon: balanceWon, myRate: myRate)
                    TodayCard(summary: today)
                    actionButtons
                    todayList
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("시간 환전소")
            .sheet(item: $sheetKind) { kind in
                AddExchangeSheet(kind: kind, myRate: myRate)
            }
        }
    }

    private var actionButtons: some View {
        HStack(spacing: 12) {
            ForEach(ExchangeKind.allCases, id: \.self) { kind in
                Button { sheetKind = kind } label: {
                    VStack(spacing: 4) {
                        Image(systemName: kind.symbol).font(.title2)
                        Text(kind.label).font(.headline)
                        Text(kind.subtitle).font(.caption).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
                .buttonStyle(.bordered)
                .tint(kind == .deposit ? .orange : .teal)
            }
        }
    }

    @ViewBuilder
    private var todayList: some View {
        if today.exchanges.isEmpty {
            Text("오늘 환전 기록이 없습니다. 일한 시간을 입금하거나, 돈으로 산 시간을 출금하세요.")
                .font(.footnote).foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 8)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Text("오늘의 환전").font(.headline)
                ForEach(today.exchanges) { ex in
                    ExchangeRow(exchange: ex)
                        .contextMenu {
                            Button(role: .destructive) { context.delete(ex) } label: { Label("삭제", systemImage: "trash") }
                        }
                }
            }
        }
    }
}

// MARK: - Cards

struct RateBoard: View {
    let profile: RateProfile

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            laborRow
            if profile.assetRate > 0 {
                Divider().padding(.vertical, 10)
                assetRow
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
    }

    private var laborRow: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("오늘의 환율 · 시간을 팔 때").font(.caption).foregroundStyle(.secondary)
                Text("1h = \(Fmt.won(profile.laborRate))").font(.title3.weight(.semibold)).monospacedDigit()
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("1만원 =").font(.caption).foregroundStyle(.secondary)
                Text(Fmt.hours(profile.laborRate > 0 ? 10_000 / profile.laborRate : 0))
                    .font(.title3.weight(.semibold)).monospacedDigit()
            }
        }
    }

    /// 자산 환율은 노동 환율과 성격이 달라 합치지 않고 따로 보여준다.
    private var assetRow: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("자산 환율 · 돈이 버는 시급").font(.caption).foregroundStyle(.secondary)
                Text("자는 동안에도 들어옵니다").font(.caption2).foregroundStyle(.tertiary)
            }
            Spacer()
            Text(Fmt.won(profile.assetRate) + "/h")
                .font(.title3.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(Color.teal)
        }
    }
}

struct BalanceCard: View {
    let balanceWon: Double
    let myRate: Double
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("잔고").font(.caption).foregroundStyle(.secondary)
            Text(Fmt.won(balanceWon)).font(.system(size: 34, weight: .bold)).monospacedDigit()
            HStack(spacing: 4) {
                Text("지금 환율로 내 시간").foregroundStyle(.secondary)
                Text(Fmt.hours(myRate > 0 ? balanceWon / myRate : 0)).fontWeight(.semibold).monospacedDigit()
            }
            .font(.footnote)
            Text("저장된 시간은 꺼내는 시점의 환율로 다시 계산됩니다. 내 시급이 오를수록 같은 잔고가 사는 내 시간은 줄어듭니다.")
                .font(.caption2).foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
    }
}

struct TodayCard: View {
    let summary: DaySummary
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(summary.date.formatted(.dateTime.month().day().weekday(.wide)))
                .font(.caption).foregroundStyle(.secondary)

            DayBar(bought: summary.boughtHours, net: summary.netHours)

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(Fmt.hours(summary.timeEquivalent)).font(.system(size: 30, weight: .bold)).monospacedDigit()
                Text("짜리 하루 · 밀도 \(Fmt.ratio(summary.density))").font(.subheadline).foregroundStyle(.secondary)
            }

            LazyVGrid(columns: [.init(), .init()], spacing: 10) {
                Stat(title: "입금 (시간 판 것)", value: Fmt.hours(summary.soldHours), sub: Fmt.won(summary.depositedWon), tint: .orange)
                Stat(title: "출금 (시간 산 것)", value: Fmt.hours(summary.boughtHours), sub: Fmt.won(summary.withdrawnWon), tint: .teal)
                Stat(title: "순증", value: Fmt.hours(summary.netHours, signed: true), sub: "돌려받은 − 벌려고 쓴", tint: summary.netHours >= 0 ? .teal : .red)
                Stat(title: "평생 관점 하루", value: Fmt.hours(summary.lifetimeHours), sub: "24 + 순증", tint: .primary)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
    }
}

/// 24시간 막대가 산 시간만큼 늘어나고, 손해는 빨간색으로 표시.
struct DayBar: View {
    let bought: Double
    let net: Double
    var body: some View {
        let loss = max(0, -net)
        let total = max(24 + bought + loss, 30)
        GeometryReader { geo in
            HStack(spacing: 0) {
                Rectangle().fill(Color.orange).frame(width: geo.size.width * 24 / total)
                Rectangle().fill(Color.teal).frame(width: geo.size.width * bought / total)
                if loss > 0 { Rectangle().fill(Color.red.opacity(0.8)).frame(width: geo.size.width * loss / total) }
                Spacer(minLength: 0)
            }
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 6))
        }
        .frame(height: 22)
        .animation(.easeOut(duration: 0.3), value: bought)
    }
}

struct Stat: View {
    let title: String
    let value: String
    let sub: String
    let tint: Color
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption2).foregroundStyle(.secondary)
            Text(value).font(.title3.weight(.semibold)).monospacedDigit().foregroundStyle(tint)
            Text(sub).font(.caption2).foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color(.systemGroupedBackground), in: RoundedRectangle(cornerRadius: 10))
    }
}

struct ExchangeRow: View {
    let exchange: Exchange
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: exchange.kind.symbol)
                .foregroundStyle(exchange.kind == .deposit ? Color.orange : Color.teal)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(exchange.title.isEmpty ? exchange.kind.label : exchange.title).font(.subheadline)
                Text(detail).font(.caption).foregroundStyle(.secondary).monospacedDigit()
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text((exchange.kind == .deposit ? "+" : "−") + Fmt.won(exchange.won)).font(.subheadline.weight(.semibold)).monospacedDigit()
                if exchange.kind == .withdrawal {
                    Text("순증 " + Fmt.hours(exchange.netHours, signed: true))
                        .font(.caption).monospacedDigit()
                        .foregroundStyle(exchange.netHours >= 0 ? Color.teal : Color.red)
                }
            }
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 10))
    }
    private var detail: String {
        switch exchange.kind {
        case .deposit:
            return "\(Fmt.hours(exchange.hours)) 판매 · 환율 \(Fmt.won(exchange.rate))/h"
        case .withdrawal:
            return "\(Fmt.hours(exchange.hours)) 구매 · 산 시급 \(Fmt.won(exchange.rate))/h · 번÷산 \(Fmt.ratio(exchange.ratio))"
        }
    }
}
