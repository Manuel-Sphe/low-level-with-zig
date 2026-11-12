# dsa

Data structures and algorithms, implemented from scratch in Zig to learn both.

Requires **Zig 0.17**. The code uses 0.17's type reflection (`field_names` / `field_types`),
which older versions don't have.

## Commands

| Command | What it does |
|---|---|
| `zig build test` | Run every test |
| `zig build test -Dtest-filter=LinkedList` | Run only tests whose name contains `LinkedList` |
| `zig build check` | Compile everything without running it (ZLS runs this on save) |
| `zig build run` | Run the playground in `src/main.zig` |

## Layout

```
src/
├── root.zig             library entry point, imported as @import("dsa")
├── main.zig             playground for trying things out
├── utils.zig            shared helpers (deep equality)
├── ds/                  data structures
│   ├── root.zig         exports every data structure
│   └── linked_list.zig
└── algo/                algorithms
    └── root.zig         exports every algorithm
```

## Adding a data structure or algorithm

1. Create the file, e.g. `src/ds/stack.zig`, with its tests at the bottom.
2. Export it from `src/ds/root.zig`:
   ```zig
   pub const Stack = @import("stack.zig").Stack;
   ```

That's all. Its tests now run with `zig build test` and are checked on save. Algorithms go in
`src/algo/` and are exported from `src/algo/root.zig` the same way.

Start each test name with the type it covers (`test "Stack: pop on empty"`), so
`-Dtest-filter=Stack` finds it.

Generic code is only compiled once it's used with a concrete type, so a method nobody calls is
never type-checked. Call every method from at least one test.

## Contents

### Data structures

- **`LinkedList(T)`**: singly linked list. `addFront`, `addBack`, `find`, `findBy`, `contains`, `len`.

### Algorithms

None yet.

### Utils

- **`utils.eql(T, a, b)`**: deep equality. Compares slices, arrays, structs, optionals and tagged
  unions by content, so two structs with equal strings are equal even when the strings live in
  different memory. Single pointers still compare by address.
- **`utils.eqlFn(T)`**: `eql` as a `fn (T, T) bool`, to pass wherever a comparison is expected.

## Using it from main.zig

```zig
const dsa = @import("dsa");

var list = dsa.ds.LinkedList(i32).init(allocator);
defer list.deinit();

try list.addBack(42);
_ = list.contains(42); // true
```
