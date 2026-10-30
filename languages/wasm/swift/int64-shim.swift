// Build-time shim for the wasm32 Swift build (see int64.sh and languages/wasm/swift/Dockerfile).
// On wasm32 Swift's Int is 32 bits; the benchmarks assume the 64-bit Int of every native target.
// The first line makes untyped integer literals Int64, the next two make the names Int and UInt mean
// the 64-bit types, and the extension lets 64-bit values index and size arrays. On a 64-bit target
// all of this is the identity (Int64 is Int there); the native-shim column of the lane measures it: equal
// differentials on 9 of the 11 shimmed benchmarks, dijkstra +0.88% and sha256 +0.098%.
typealias IntegerLiteralType = Int64
typealias Int = Int64
typealias UInt = UInt64
extension Array {
    subscript(i: Int64) -> Element {
        get { return self[Swift.Int(truncatingIfNeeded: i)] }
        set { self[Swift.Int(truncatingIfNeeded: i)] = newValue }
    }
    init(repeating v: Element, count: Int64) { self.init(repeating: v, count: Swift.Int(truncatingIfNeeded: count)) }
    mutating func reserveCapacity(_ n: Int64) { self.reserveCapacity(Swift.Int(truncatingIfNeeded: n)) }
}
