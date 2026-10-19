import XCTest
@testable import DejaVuScreensaver

final class CalendarDatePickerTests: XCTestCase {
    func testMonthGridUsesTheCalendarsFirstWeekdayAndIncludesEveryDay() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.firstWeekday = 2
        let october2023 = calendar.date(from: DateComponents(year: 2023, month: 10, day: 1))!

        let days = CalendarMonth.days(containing: october2023, calendar: calendar)

        XCTAssertEqual(days.count, 42)
        XCTAssertEqual(days.prefix(6).compactMap { $0 }.count, 0)
        XCTAssertEqual(days.compactMap { $0 }.count, 31)
        XCTAssertEqual(calendar.component(.day, from: days[6]!), 1)
        XCTAssertEqual(calendar.component(.day, from: days[36]!), 31)
    }

    func testChangingMonthOrYearPreservesAndClampsTheSelectedDay() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let january31 = calendar.date(from: DateComponents(year: 2023, month: 1, day: 31))!
        let february14 = calendar.date(from: DateComponents(year: 2026, month: 2, day: 14))!
        let february2023 = calendar.date(from: DateComponents(year: 2023, month: 2, day: 1))!
        let february2024 = calendar.date(from: DateComponents(year: 2024, month: 2, day: 1))!
        let february2027 = calendar.date(from: DateComponents(year: 2027, month: 2, day: 1))!

        let nonLeapDate = CalendarMonth.date(in: february2023, preservingDayFrom: january31, calendar: calendar)
        let leapDate = CalendarMonth.date(in: february2024, preservingDayFrom: january31, calendar: calendar)
        let nextYearDate = CalendarMonth.date(in: february2027, preservingDayFrom: february14, calendar: calendar)

        XCTAssertEqual(calendar.component(.day, from: nonLeapDate), 28)
        XCTAssertEqual(calendar.component(.day, from: leapDate), 29)
        XCTAssertEqual(calendar.dateComponents([.year, .month, .day], from: nextYearDate), DateComponents(year: 2027, month: 2, day: 14))
    }
}
