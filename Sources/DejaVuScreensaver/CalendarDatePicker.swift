import SwiftUI

struct CalendarDateButton: View {
    let label: String
    @Binding var selection: Date
    var minimumDate: Date?
    var onPresentationChange: (Bool) -> Void = { _ in }
    @State private var isPresented = false
    @State private var draftSelection = Date()

    var body: some View {
        Button {
            draftSelection = selection
            isPresented = true
        } label: {
            HStack(spacing: 5) {
                Text(label)
                    .foregroundStyle(.secondary)
                Text(selection.formatted(date: .abbreviated, time: .omitted))
                Image(systemName: "calendar")
                    .foregroundStyle(.secondary)
            }
        }
        .popover(isPresented: $isPresented, arrowEdge: .bottom) {
            CalendarDatePicker(
                selection: $draftSelection,
                minimumDate: minimumDate,
                onSelect: { isPresented = false }
            )
        }
        .onChange(of: isPresented) { _, isPresented in
            onPresentationChange(isPresented)
            guard !isPresented else { return }
            let newSelection = draftSelection
            Task { @MainActor in
                await Task.yield()
                selection = newSelection
            }
        }
        .accessibilityLabel("\(label), \(selection.formatted(date: .long, time: .omitted))")
    }
}

private struct CalendarDatePicker: View {
    @Binding var selection: Date
    let minimumDate: Date?
    let onSelect: () -> Void
    @State private var displayedMonth: Date
    @State private var isChoosingYear = false

    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.fixed(30), spacing: 4), count: 7)

    init(selection: Binding<Date>, minimumDate: Date?, onSelect: @escaping () -> Void) {
        _selection = selection
        self.minimumDate = minimumDate
        self.onSelect = onSelect
        _displayedMonth = State(initialValue: CalendarMonth.start(of: selection.wrappedValue))
    }

    var body: some View {
        VStack(spacing: 10) {
            header

            Group {
                if isChoosingYear {
                    yearGrid
                } else {
                    dayGrid
                }
            }
            .frame(height: 226, alignment: .top)
        }
        .padding(12)
        .onAppear {
            displayedMonth = CalendarMonth.start(of: selection, calendar: calendar)
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Button {
                moveMonth(by: -1)
            } label: {
                Image(systemName: "chevron.left")
            }
            .buttonStyle(.plain)
            .disabled(!canMoveBackward)
            .accessibilityLabel("Previous month")

            Spacer(minLength: 4)

            Picker("Month", selection: monthBinding) {
                ForEach(Array(calendar.monthSymbols.enumerated()), id: \.offset) { index, month in
                    Text(month)
                        .tag(index + 1)
                        .disabled(!isMonthAvailable(index + 1))
                }
            }
            .labelsHidden()
            .fixedSize()

            Button {
                withAnimation(.easeOut(duration: 0.12)) {
                    isChoosingYear.toggle()
                }
            } label: {
                HStack(spacing: 4) {
                    Text(String(displayedYear))
                        .monospacedDigit()
                    Image(systemName: isChoosingYear ? "chevron.up" : "chevron.down")
                        .font(.caption2)
                }
            }
            .buttonStyle(.bordered)
            .fixedSize()
            .accessibilityLabel("Year \(displayedYear)")
            .accessibilityHint("Choose year")

            Spacer(minLength: 4)

            Button {
                moveMonth(by: 1)
            } label: {
                Image(systemName: "chevron.right")
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Next month")
        }
    }

    private var dayGrid: some View {
        LazyVGrid(columns: columns, spacing: 4) {
            ForEach(Array(CalendarMonth.weekdaySymbols(calendar: calendar).enumerated()), id: \.offset) { _, symbol in
                Text(symbol)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 30, height: 22)
            }

            ForEach(Array(CalendarMonth.days(containing: displayedMonth, calendar: calendar).enumerated()), id: \.offset) { _, date in
                if let date {
                    dayButton(date)
                } else {
                    Color.clear.frame(width: 30, height: 30)
                }
            }
        }
    }

    private var yearGrid: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
                    ForEach(yearRange, id: \.self) { year in
                        Button {
                            setDisplayedMonth(month: displayedMonthNumber, year: year)
                            withAnimation(.easeOut(duration: 0.12)) {
                                isChoosingYear = false
                            }
                        } label: {
                            Text(String(year))
                                .monospacedDigit()
                                .frame(maxWidth: .infinity, minHeight: 30)
                                .foregroundStyle(year == displayedYear ? Color.white : Color.primary)
                                .background(year == displayedYear ? Color.accentColor : Color.clear, in: Capsule())
                        }
                        .buttonStyle(.plain)
                        .id(year)
                        .accessibilityAddTraits(year == displayedYear ? .isSelected : [])
                    }
                }
                .padding(.horizontal, 2)
            }
            .onAppear {
                proxy.scrollTo(displayedYear, anchor: .center)
            }
        }
    }

    private func dayButton(_ date: Date) -> some View {
        let isSelected = calendar.isDate(date, inSameDayAs: selection)
        let isToday = calendar.isDateInToday(date)
        let isAvailable = minimumDate.map { date >= calendar.startOfDay(for: $0) } ?? true

        return Button {
            selection = calendar.startOfDay(for: date)
            onSelect()
        } label: {
            Text(date.formatted(.dateTime.day()))
                .frame(width: 30, height: 30)
                .foregroundStyle(isSelected ? Color.white : Color.primary)
                .background {
                    if isSelected {
                        Circle().fill(Color.accentColor)
                    } else if isToday {
                        Circle().stroke(Color.accentColor)
                    }
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isAvailable)
        .accessibilityLabel(date.formatted(date: .long, time: .omitted))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var monthBinding: Binding<Int> {
        Binding(
            get: { calendar.component(.month, from: displayedMonth) },
            set: { setDisplayedMonth(month: $0, year: displayedYear) }
        )
    }

    private var displayedMonthNumber: Int {
        calendar.component(.month, from: displayedMonth)
    }

    private var displayedYear: Int {
        calendar.component(.year, from: displayedMonth)
    }

    private var yearRange: ClosedRange<Int> {
        let currentYear = calendar.component(.year, from: Date())
        let minimumYear = minimumDate.map { calendar.component(.year, from: $0) } ?? 1800
        return min(minimumYear, displayedYear)...max(currentYear, displayedYear)
    }

    private var canMoveBackward: Bool {
        guard let minimumDate else { return true }
        return displayedMonth > CalendarMonth.start(of: minimumDate, calendar: calendar)
    }

    private func isMonthAvailable(_ month: Int) -> Bool {
        guard let minimumDate else { return true }
        let minimumComponents = calendar.dateComponents([.year, .month], from: minimumDate)
        return displayedYear != minimumComponents.year || month >= (minimumComponents.month ?? 1)
    }

    private func moveMonth(by value: Int) {
        guard let date = calendar.date(byAdding: .month, value: value, to: displayedMonth) else { return }
        setDisplayedMonth(month: calendar.component(.month, from: date), year: calendar.component(.year, from: date))
    }

    private func setDisplayedMonth(month: Int, year: Int) {
        guard let date = calendar.date(from: DateComponents(year: year, month: month, day: 1)) else { return }
        if let minimumDate {
            displayedMonth = max(date, CalendarMonth.start(of: minimumDate, calendar: calendar))
        } else {
            displayedMonth = date
        }
        let preservedDate = CalendarMonth.date(
            in: displayedMonth,
            preservingDayFrom: selection,
            calendar: calendar
        )
        selection = max(preservedDate, minimumDate.map { calendar.startOfDay(for: $0) } ?? .distantPast)
    }
}

enum CalendarMonth {
    static func start(of date: Date, calendar: Calendar = .current) -> Date {
        let components = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: components) ?? date
    }

    static func weekdaySymbols(calendar: Calendar) -> [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let index = calendar.firstWeekday - 1
        return Array(symbols[index...] + symbols[..<index])
    }

    static func days(containing date: Date, calendar: Calendar) -> [Date?] {
        let firstDay = start(of: date, calendar: calendar)
        guard let dayRange = calendar.range(of: .day, in: .month, for: firstDay) else { return [] }
        let firstWeekday = calendar.component(.weekday, from: firstDay)
        let leadingSlots = (firstWeekday - calendar.firstWeekday + 7) % 7
        var days = Array<Date?>(repeating: nil, count: leadingSlots)
        days += dayRange.compactMap { day in
            calendar.date(byAdding: .day, value: day - 1, to: firstDay)
        }
        days += Array(repeating: nil, count: (7 - days.count % 7) % 7)
        return days
    }

    static func date(in month: Date, preservingDayFrom selectedDate: Date, calendar: Calendar) -> Date {
        let firstDay = start(of: month, calendar: calendar)
        let selectedDay = calendar.component(.day, from: selectedDate)
        let lastDay = calendar.range(of: .day, in: .month, for: firstDay)?.count ?? 1
        return calendar.date(byAdding: .day, value: min(selectedDay, lastDay) - 1, to: firstDay) ?? firstDay
    }
}
