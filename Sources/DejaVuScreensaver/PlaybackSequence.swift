import Foundation

struct PlaybackSequence {
    private(set) var history: [Int] = []
    private(set) var cursor = -1
    private var bag: [Int] = []
    private var itemCount = 0

    var current: Int? {
        guard history.indices.contains(cursor) else { return nil }
        return history[cursor]
    }

    mutating func reset(itemCount: Int) {
        self.itemCount = max(0, itemCount)
        history = []
        cursor = -1
        bag = Array(0..<self.itemCount).shuffled()
    }

    mutating func next() -> Int? {
        guard itemCount > 0 else { return nil }

        if cursor + 1 < history.count {
            cursor += 1
            return history[cursor]
        }

        if bag.isEmpty {
            bag = Array(0..<itemCount).filter { $0 != current }.shuffled()
            if bag.isEmpty, let current { bag = [current] }
        }

        guard let next = bag.popLast() else { return nil }
        history.append(next)
        cursor = history.count - 1
        return next
    }

    mutating func previous() -> Int? {
        guard cursor > 0 else { return current }
        cursor -= 1
        return history[cursor]
    }
}
