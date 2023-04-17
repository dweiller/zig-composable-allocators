# Composable allocators

This is an implementation in Zig of the ideas [presented](https://www.youtube.com/watch?v=LIb3L4vKZ7U) by Andrei Alexandrescu about composable allocators.

The allocators are (mostly) implemented as comptime generics conforming to an interface that is (optionally) a superset of `std.mem.Allocator`, except that concrete types are used instead of `*anyopaque`.

The following allocators are either currently implemented (those with a tick) or are planned to be:

  - [x] `Std` (for wrapping a `std.mem.Allocator`)
  - [x] `Null`
  - [x] `FixedBuffer` (bump allocator with fixed memory buffer)
  - [x] `Fallback`
  - [x] `Stack` (a thin wrapper around `FixedBuffer` putting the buffer on the stack)
  - [ ] `Affix` (add optional extra data before/after each allocation)
  - [x] `FreeList` (allocates blocks of a specific size; non-thread-safe)
  - [ ] `ThreadSafeFreeList` (a thread-safe version of `FreeList`, allowing other threads to free, but not allocate)
  - [ ] `BitMapped` (allocates blocks of a specific size, tracking occupancy with a bitmap)
  - [ ] `Cascading` (holds a collection of allocators in use (all the same type), adding a new one when they are all full)
  - [x] `Segregated` (chooses between two allocators based on a size threshold)
  - [ ] `Bucket` (like `Segregated`, but has multiple size classes)

All of these (except for the first three) are generic over other allocator types that they wrap, allowing them to be composed to create complex allocation strategies in a relatively simple way; for example, an allocator that allocates on the stack (as a bump allocator) but falls back to a `std.heap.GeneralPurposeAllocator` can be implemented as:
```zig
const ca = @import("/path/to/composable-allocator/lib.zig");

pub fn main() void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var test_allocator: ca.Fallback(ca.Stack(1024), ca.Std) = undefined;
    test_allocator.primary.initInPlaceExtra(.{gpa.allocator()});
    const a = ca.allocator(&test_allocator);
}
```

In the above, `a` is a `std.mem.Allocator` that will first try to use a bump allocator with 1024 bytes on the stack before reverting to using `std.mem.GeneralPurposeAllocator(.{})`.

## WIP
If you have suggestions, would like to contribute some allocators, or have issues using anything issues and PRs are welcome.
