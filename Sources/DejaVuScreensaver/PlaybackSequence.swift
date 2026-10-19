import Foundation

struct PlaybackSequence {
    private(set) var history: [Int] = []
    private(set) var cursor = -1
    private var bag: [Int] = []
    private var itemCount = 0
    private var order: PhotoOrder = .random

    var current: Int? {
        guard history.indices.contains(cursor) else { return nil }
        return history[cursor]
    }

    mutating func reset(itemCount: Int, order: PhotoOrder = .random) {
        self.itemCount = max(0, itemCount)
        self.order = order
        history = []
        cursor = -1
        refillBag()
    }

    mutating func next() -> Int? {
        guard itemCount > 0 else { return nil }

        if cursor + 1 < history.count {
            cursor += 1
            return history[cursor]
        }

        if bag.isEmpty {
            refillBag()
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

    private mutating func refillBag() {
        let indices = Array(0..<itemCount).filter { order != .random || $0 != current }
        switch order {
        case .random: bag = indices.shuffled()
        case .chronological: bag = Array(indices.reversed())
        case .reverseChronological: bag = indices
        }
    }
}
