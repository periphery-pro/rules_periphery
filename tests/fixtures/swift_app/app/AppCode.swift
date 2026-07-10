struct UsedSymbol {
    func greet() -> String { "hi" }
}

// Never referenced; e2e.sh asserts Periphery reports it.
struct UnusedSymbol {
    func unused() -> Int { 0 }
}
