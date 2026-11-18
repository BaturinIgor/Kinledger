import Foundation
import Testing
@testable import Kinledger

struct FormatTests {
    @Test func exactDuration() {
        #expect(Format.duration(minutes: 25) == "25 min")
        #expect(Format.duration(minutes: 120) == "2 h")
        #expect(Format.duration(minutes: 130) == "2 h 10 min")
    }

    @Test func summaryRoundsToHalfHours() {
        #expect(Format.durationSummary(minutes: 0) == "0 h")
        #expect(Format.durationSummary(minutes: 755) == "12.5 h")
        #expect(Format.durationSummary(minutes: 1890) == "31.5 h")
        #expect(Format.durationSummary(minutes: 1800) == "30 h")
    }

    @Test func moneyDropsCentsOnlyWhenWhole() {
        #expect(Format.money(cents: 4280) == "$42.80")
        #expect(Format.money(cents: 1800) == "$18")
        #expect(Format.money(cents: 0) == "$0")
    }
}

struct SummaryTests {
    @Test func outOfPocketCountsOnlyWhatICharged() {
        // Sample month: $42.80 + $18 paid by me; $67.15 paid by the parent does not count.
        let totals = SampleData.entries.totals()
        #expect(totals.outOfPocketCents == 6080)
        #expect(totals.minutes == 25 + 130 + 540 + 60)
        #expect(totals.visits == 3)
    }

    @Test func inMonthFiltersByCareDate() {
        let october = SampleData.date(2026, 10, 31, 12, 0)
        #expect(SampleData.entries.inMonth(of: october).isEmpty)
        #expect(SampleData.entries.inMonth(of: SampleData.month).count == 4)
    }

    @Test func recentIsNewestFirst() {
        let titles = SampleData.entries.recent(2).map(\.title)
        #expect(titles == ["Pharmacy pickup", "Dr. Patel, cardiology"])
    }
}
