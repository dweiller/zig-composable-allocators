const std = @import("std");

const helpers = @import("helpers.zig");

const assert = std.debug.assert;

pub fn Interface(comptime T: type) type {
    return struct {
        const required = struct {
            /// Attempt to allocate exactly `len` bytes aligned to `1 << ptr_align`.
            ///
            /// `ret_addr` is optionally provided as the first return address of the
            /// allocation call stack. If the value is `0` it means no return address
            /// has been provided.
            const alloc = fn (self: *T, len: usize, ptr_align: u8, ret_addr: usize) ?[*]u8;

            /// Attempt to expand or shrink memory in place. `buf.len` must equal the
            /// length requested from the most recent successful call to `alloc` or
            /// `resize`. `buf_align` must equal the same value that was passed as the
            /// `ptr_align` parameter to the original `alloc` call.
            ///
            /// A result of `true` indicates the resize was successful and the
            /// allocation now has the same address but a size of `new_len`. `false`
            /// indicates the resize could not be completed without moving the
            /// allocation to a different address.
            ///
            /// `new_len` must be greater than zero.
            ///
            /// `ret_addr` is optionally provided as the first return address of the
            /// allocation call stack. If the value is `0` it means no return address
            /// has been provided.
            const resize = fn (self: *T, buf: []u8, buf_align: u8, new_len: usize, ret_addr: usize) bool;

            /// Free and invalidate a buffer.
            ///
            /// `buf.len` must equal the most recent length returned by `alloc` or
            /// given to a successful `resize` call.
            ///
            /// `buf_align` must equal the same value that was passed as the
            /// `ptr_align` parameter to the original `alloc` call.
            ///
            /// `ret_addr` is optionally provided as the first return address of the
            /// allocation call stack. If the value is `0` it means no return address
            /// has been provided.
            const free = fn (self: *T, buf: []u8, buf_align: u8, ret_addr: usize) void;
        };

        const optional = struct {
            usingnamespace if (@hasDecl(T, "init")) struct {
                /// initialise an allocator
                pub const init = fn () T;

                comptime {
                    assert(init == @TypeOf(T.init));
                }
            } else struct {};

            usingnamespace if (@hasDecl(T, "initInPlace")) struct {
                pub const initInPlace = fn (self: *T) void;

                comptime {
                    assert(initInPlace == @TypeOf(T.initInPlace));
                }
            } else struct {};

            usingnamespace if (@hasDecl(T, "default_init")) struct {
                pub const default_init = T.default_init;

                comptime {
                    assert(@TypeOf(default_init) == T);
                }
            } else struct {};

            usingnamespace if (@hasDecl(T, "initExtra")) struct {
                pub const initExtra = @TypeOf(T.initExtra);

                comptime {
                    assert(@typeInfo(initExtra).Fn.return_type == T);
                }
            } else struct {};

            usingnamespace if (@hasDecl(T, "initInPlaceExtra")) struct {
                pub const initInPlaceExtra = @TypeOf(T.initInPlaceExtra);

                comptime {
                    assert(@typeInfo(initInPlaceExtra).Fn.params[0].type == *T);
                    assert(@typeInfo(initInPlaceExtra).Fn.return_type == void);
                }
            } else struct {};

            /// Checks whether the allocator owns the memory for `buf`.
            /// Composite allocators will generally pass `buf` to the underlying
            /// allocators, so it is not advisable to have composite allocators
            /// share backing allocators that define `owns`
            const owns = fn (self: *T, buf: []u8) bool;

            /// Attempt to return all remaining memory available to the allocator, or
            /// return null, if there isn't any.
            const allocAll = fn (self: *T) ?[]u8;

            /// Free all allocated memory.
            const freeAll = fn (self: *T) void;
        };
    };
}

pub fn allocator(a: anytype) std.mem.Allocator {
    const Self = @typeInfo(@TypeOf(a)).Pointer.child;

    comptime {
        validateAllocator(Self);
    }

    return .{
        .ptr = a,
        .vtable = &.{
            .alloc = &struct {
                fn alloc(ptr: *anyopaque, len: usize, log2_ptr_align: u8, ret_addr: usize) ?[*]u8 {
                    const self: *Self = @ptrCast(@alignCast(ptr));
                    return self.alloc(len, log2_ptr_align, ret_addr);
                }
            }.alloc,
            .resize = &struct {
                fn resize(ptr: *anyopaque, buf: []u8, log2_buf_align: u8, new_len: usize, ret_addr: usize) bool {
                    const self: *Self = @ptrCast(@alignCast(ptr));
                    return self.resize(buf, log2_buf_align, new_len, ret_addr);
                }
            }.resize,
            .free = &struct {
                fn free(ptr: *anyopaque, buf: []u8, log2_buf_align: u8, ret_addr: usize) void {
                    const self: *Self = @ptrCast(@alignCast(ptr));
                    self.free(buf, log2_buf_align, ret_addr);
                }
            }.free,
        },
    };
}

pub fn validateAllocator(comptime T: type) void {
    comptime {
        for (std.meta.declarations(Interface(T).required)) |decl| {
            const E = @field(Interface(T).required, decl.name);
            if (!@hasDecl(T, decl.name)) {
                @compileError("type " ++ @typeName(T) ++ " must have declaration " ++ decl.name ++
                    " of type " ++ @typeName(T));
            }
            const D = @TypeOf(@field(T, decl.name));
            if (D != E) {
                @compileError("declaration " ++ decl.name ++ " in type " ++ @typeName(T) ++
                    " is expected to have type " ++ @typeName(E) ++ ", found " ++ @typeName(D));
            }
        }

        for (std.meta.declarations(Interface(T).optional)) |decl| {
            if (@hasDecl(T, decl.name)) {
                if (std.mem.startsWith(u8, decl.name, "usingnamespace_")) {
                    // BUG: this doesn't work, there seems to be limitations/bugs in @typeInfo
                    //      that prevent getting the decls of an included namespace
                    //      (the info.decls slice below always has length 0.
                    const ns = @field(Interface(T).optional, decl.name);
                    const info = @typeInfo(ns).Struct;
                    if (info.decls.len == 0) continue;
                    const E = @field(ns, info.decls[0].name);
                    const D = @TypeOf(@field(@field(T, decl.name), info.decls[0].name));
                    if (D != E) {
                        @compileError("declaration " ++ decl.name ++ " in type " ++ @typeName(T) ++
                            " is expected to have type " ++ @typeName(E) ++ ", found " ++ @typeName(D));
                    }
                } else {
                    const E = @field(Interface(T).optional, decl.name);
                    const D = @TypeOf(@field(T, decl.name));
                    if (D != E) {
                        @compileError("declaration " ++ decl.name ++ " in type " ++ @typeName(T) ++
                            " is expected to have type " ++ @typeName(E) ++ ", found " ++ @typeName(D));
                    }
                }
            }
        }
    }
}

pub const Std = struct {
    a: std.mem.Allocator,

    pub fn initExtra(a: std.mem.Allocator) Std {
        return Std{ .a = a };
    }

    pub fn alloc(self: *Std, len: usize, log2_ptr_align: u8, ret_addr: usize) ?[*]u8 {
        return self.a.rawAlloc(len, log2_ptr_align, ret_addr);
    }

    pub fn resize(self: *Std, buf: []u8, log2_buf_align: u8, new_len: usize, ret_addr: usize) bool {
        return self.a.rawResize(buf, log2_buf_align, new_len, ret_addr);
    }

    pub fn free(self: *Std, buf: []u8, log2_buf_align: u8, ret_addr: usize) void {
        return self.a.rawFree(buf, log2_buf_align, ret_addr);
    }
};

pub const Null = struct {
    pub fn alloc(_: *Null, _: usize, _: u8, _: usize) ?[*]u8 {
        return null;
    }

    pub fn resize(_: *Null, buf: []u8, _: u8, new_len: usize, _: usize) bool {
        assert(buf.len == 0);
        return new_len == 0;
    }

    pub fn free(_: *Null, buf: []u8, _: u8, _: usize) void {
        assert(buf.len == 0);
    }

    pub fn allocAll(_: *Null) ?[]u8 {
        return null;
    }

    pub fn freeAll(_: *Null) void {}
};

pub const FixedBuffer = struct {
    buffer: []u8,
    len: usize,

    const Self = @This();

    fn isLastAllocation(self: Self, buf: []u8) bool {
        return self.buffer.ptr + self.len == buf.ptr + buf.len;
    }

    pub fn alloc(self: *Self, len: usize, log2_ptr_align: u8, ret_addr: usize) ?[*]u8 {
        _ = ret_addr;
        const ptr_align = @as(usize, 1) << @intCast(log2_ptr_align);
        const align_offset = std.mem.alignPointerOffset(self.buffer.ptr + self.len, ptr_align) orelse return null;
        const start_index = self.len + align_offset;
        const new_len = start_index + len;
        if (new_len > self.buffer.len) return null;
        self.len = new_len;
        return self.buffer.ptr + start_index;
    }

    pub fn resize(self: *Self, buf: []u8, log2_buf_align: u8, new_len: usize, ret_addr: usize) bool {
        _ = log2_buf_align;
        _ = ret_addr;
        assert(self.owns(buf));

        if (!self.isLastAllocation(buf)) {
            if (new_len > buf.len) return false;
            return true;
        }

        if (new_len <= buf.len) {
            self.len -= buf.len - new_len;
            return true;
        }

        const new_total_len = self.len + (new_len - buf.len);
        if (new_total_len > self.buffer.len) return false;
        self.len = new_total_len;
        return true;
    }

    pub fn free(self: *Self, buf: []u8, log2_buf_align: u8, ret_addr: usize) void {
        _ = log2_buf_align;
        _ = ret_addr;
        assert(self.owns(buf));

        if (self.isLastAllocation(buf)) {
            self.len -= buf.len;
        }
    }

    pub fn owns(self: *Self, buf: []u8) bool {
        return sliceContainsSlice(self.buffer, buf);
    }

    pub fn allocAll(self: *Self) ?[]u8 {
        if (self.len == self.buffer.len) return null;
        self.len = self.buffer.len;
        return self.buffer[self.len..self.buffer.len];
    }

    pub fn freeAll(self: *Self) void {
        self.len = 0;
    }
};

pub fn Fallback(comptime PrimaryAllocator: type, comptime FallbackAllocator: type) type {
    comptime {
        validateAllocator(PrimaryAllocator);
        validateAllocator(FallbackAllocator);
    }

    return struct {
        primary: PrimaryAllocator,
        fallback: FallbackAllocator,

        const Self = @This();

        pub fn alloc(self: *Self, len: usize, ptr_align: u8, ret_addr: usize) ?[*]u8 {
            return self.primary.alloc(len, ptr_align, ret_addr) orelse {
                return self.fallback.alloc(len, ptr_align, ret_addr);
            };
        }

        pub fn resize(self: *Self, buf: []u8, buf_align: u8, new_len: usize, ret_addr: usize) bool {
            if (self.primary.owns(buf)) {
                return self.primary.resize(buf, buf_align, new_len, ret_addr);
            } else {
                return self.fallback.resize(buf, buf_align, new_len, ret_addr);
            }
        }

        pub fn free(self: *Self, buf: []u8, buf_align: u8, ret_addr: usize) void {
            if (self.primary.owns(buf)) {
                self.primary.free(buf, buf_align, ret_addr);
            } else {
                self.fallback.free(buf, buf_align, ret_addr);
            }
        }

        pub usingnamespace if (helpers.hasInit2(PrimaryAllocator, FallbackAllocator)) struct {
            pub const init = helpers.init2(Self, "primary", PrimaryAllocator, "fallback", FallbackAllocator);
        } else struct {};

        pub usingnamespace if (helpers.hasDefaultInit2(PrimaryAllocator, FallbackAllocator)) struct {
            pub const default_init = helpers.defaultInit2(Self, "primary", PrimaryAllocator, "fallback", FallbackAllocator);
        } else struct {};

        pub usingnamespace if (helpers.hasInitInPlace2(PrimaryAllocator, FallbackAllocator)) struct {
            pub const initInPlace = helpers.initInPlace2(Self, "primary", PrimaryAllocator, "fallback", FallbackAllocator);
        } else struct {};

        pub usingnamespace if (helpers.hasInitExtra2(PrimaryAllocator, FallbackAllocator)) struct {
            pub const initExtra = helpers.initExtra2(Self, "primary", PrimaryAllocator, "fallback", FallbackAllocator);
        } else struct {};

        pub usingnamespace if (helpers.hasInitInPlaceExtra2(PrimaryAllocator, FallbackAllocator)) struct {
            pub const initInPlaceExtra = helpers.initInPlaceExtra2(Self, "primary", PrimaryAllocator, "fallback", FallbackAllocator);
        } else struct {};

        pub usingnamespace if (@hasDecl(FallbackAllocator, "owns")) struct {
            pub fn owns(self: *Self, buf: []u8) bool {
                return self.primary.owns(buf) or self.fallback.owns(buf);
            }
        } else struct {};

        pub usingnamespace if (@hasDecl(PrimaryAllocator, "freeAll") and @hasDecl(FallbackAllocator, "freeAll")) struct {
            pub fn freeAll(self: *Self) void {
                self.primary.freeAll();
                self.fallback.freeAll();
            }
        } else struct {};
    };
}

fn sliceContainsSlice(slice: []u8, other: []u8) bool {
    return @intFromPtr(slice.ptr) <= @intFromPtr(other.ptr) and
        @intFromPtr(slice.ptr) + slice.len >= @intFromPtr(other.ptr) + other.len;
}

pub fn Stack(comptime capacity: usize) type {
    return struct {
        buffer: [capacity]u8 = undefined,
        fba: FixedBuffer,

        const Self = @This();

        pub fn initInPlace(self: *Self) void {
            self.fba = FixedBuffer{ .buffer = &self.buffer, .len = 0 };
        }

        pub fn alloc(self: *Self, len: usize, log2_ptr_align: u8, ret_addr: usize) ?[*]u8 {
            return self.fba.alloc(len, log2_ptr_align, ret_addr);
        }

        pub fn resize(self: *Self, buf: []u8, log2_buf_align: u8, new_len: usize, ret_addr: usize) bool {
            return self.fba.resize(buf, log2_buf_align, new_len, ret_addr);
        }

        pub fn free(self: *Self, buf: []u8, log2_buf_align: u8, ret_addr: usize) void {
            self.fba.free(buf, log2_buf_align, ret_addr);
        }

        pub fn owns(self: *Self, buf: []u8) bool {
            return self.fba.owns(buf);
        }

        pub fn allocAll(self: *Self) ?[]u8 {
            return self.fba.allocAll();
        }

        pub fn freeAll(self: *Self) void {
            self.fba.freeAll();
        }
    };
}

pub fn FreeList(
    comptime BackingAllocator: type,
    comptime block_size: usize,
    comptime alloc_count: usize, // number of blocks to allocate at a time,
    comptime max_list_size: ?usize,
) type {
    comptime {
        validateAllocator(BackingAllocator);
    }

    return struct {
        free_list: std.SinglyLinkedList(void),
        free_size: usize,
        backing_allocator: BackingAllocator,

        const Self = @This();

        const Node = std.SinglyLinkedList(void).Node;
        const log2_block_align = @ctz(block_size);
        const block_align = 1 << log2_block_align;
        comptime {
            assert(alloc_count != 0);
            assert(@sizeOf(Node) <= block_size);
            assert(block_size % block_align == 0);
            assert(@alignOf(Node) <= block_align);
        }

        fn addBlocksToFreeList(self: *Self, blocks: []align(block_align) [block_size]u8) void {
            var i: usize = blocks.len;
            while (i > 0) : (i -= 1) {
                var node: *Node = @ptrCast(@alignCast(&blocks[i - 1]));
                self.free_list.prepend(node);
            }
            self.free_size += blocks.len;
        }

        pub fn alloc(self: *Self, len: usize, log2_ptr_align: u8, ret_addr: usize) ?[*]u8 {
            // TODO: should we check len < block_size and/or check if ptr_align == block_size
            //       to try and avoid gcd calculation?

            // blocks are always aligned to block_size, so the requested alignment
            // must divide block_size
            assert(block_align >= (@as(usize, 1) << @intCast(log2_ptr_align)));
            assert(len <= block_size);

            if (self.free_list.popFirst()) |node| {
                self.free_size -= 1;
                return @ptrCast(node);
            }

            if (alloc_count > 1 and if (max_list_size) |max| self.free_size + alloc_count - 1 < max else true) {
                const ptr = self.backing_allocator.alloc(block_size * alloc_count, block_align, ret_addr);
                const block_ptr: [*]align(block_align)[block_size]u8 = @ptrCast(@alignCast(ptr));
                const blocks = block_ptr[1..alloc_count];
                self.addBlocksToFreeList(blocks);
                return ptr;
            } else {
                return self.backing_allocator.alloc(block_size * alloc_count, block_align, ret_addr);
            }
        }

        pub fn resize(self: *Self, buf: []u8, log2_buf_align: u8, new_len: usize, ret_addr: usize) bool {
            _ = self;
            _ = buf;
            _ = log2_buf_align;
            _ = ret_addr;
            return new_len <= block_size;
        }

        pub fn free(self: *Self, buf: []u8, log2_buf_align: u8, ret_addr: usize) void {
            assert(block_align >= (@as(usize, 1) << @intCast(log2_buf_align)));
            assert(block_align % (@as(usize, 1) << @intCast(log2_buf_align)) == 0);

            if (max_list_size == null or self.free_size < max_list_size.?) {
                const node: *align(block_align) Node = @ptrCast(@alignCast(buf.ptr));
                self.free_list.prepend(node);
                self.free_size += 1;
                return;
            } else {
                self.backing_allocator.free(buf, log2_buf_align, ret_addr);
            }
        }

        pub fn freeAll(self: *Self) void {
            while (self.free_list.popFirst()) |node| {
                const casted_ptr: *align(block_align) [block_size]u8 = @alignCast(@ptrCast(node));
                self.backing_allocator.free(casted_ptr, log2_block_align, @returnAddress());
            }
        }

        pub usingnamespace if (@hasDecl(BackingAllocator, "init")) struct {
            pub fn init() Self {
                return Self{
                    .free_list = .{ .first = null },
                    .free_size = 0,
                    .backing_allocator = BackingAllocator.init(),
                };
            }
        } else struct {};

        pub usingnamespace if (@hasDecl(BackingAllocator, "initExtra")) struct {
            pub fn initExtra(args: std.meta.ArgsTuple(@TypeOf(BackingAllocator.initExtra))) Self {
                return Self{
                    .free_list = .{ .first = null },
                    .free_size = 0,
                    .backing_allocator = @call(.auto, BackingAllocator.initExtra, args),
                };
            }
        } else struct {};

        pub usingnamespace if (@hasDecl(BackingAllocator, "initInPlace")) struct {
            pub fn initInPlace(self: *Self) void {
                self.free_list = .{ .first = null };
                self.free_size = 0;
                self.backing_allocator.initInPlace();
            }
        } else struct {};

        pub usingnamespace if (@hasDecl(BackingAllocator, "initInPlaceExtra")) struct {
            pub fn initInPlaceExtra(self: *Self, args: helpers.ArgsIIPE(@TypeOf(BackingAllocator.initInPlaceExtra))) void {
                self.free_list = .{ .first = null };
                self.free_size = 0;
                @call(.auto, self.backing_allocator.initInPlaceExtra, .{&self.backing_allocator} ++ args);
            }
        } else struct {};

        pub usingnamespace if (@hasDecl(BackingAllocator, "default_init")) struct {
            pub fn init() Self {
                return Self{
                    .free_list = .{ .first = null },
                    .free_size = 0,
                    .backing_allocator = BackingAllocator.default_init,
                };
            }
        } else struct {};
    };
}

pub fn Segregated(
    comptime SmallAllocator: type,
    comptime LargeAllocator: type,
    comptime threshold: usize, // largest size to use the small allocator for
) type {
    comptime {
        validateAllocator(SmallAllocator);
        validateAllocator(LargeAllocator);
    }

    return struct {
        small_allocator: SmallAllocator,
        large_allocator: LargeAllocator,

        const Self = @This();

        pub fn alloc(self: *Self, len: usize, log2_ptr_align: u8, ret_addr: usize) ?[*]u8 {
            return if (len <= threshold)
                self.small_allocator.alloc(len, log2_ptr_align, ret_addr)
            else
                self.large_allocator.alloc(len, log2_ptr_align, ret_addr);
        }

        pub fn resize(self: *Self, buf: []u8, log2_buf_align: u8, new_len: usize, ret_addr: usize) bool {
            return if (buf.len <= threshold and new_len <= threshold)
                self.small_allocator.resize(buf, log2_buf_align, new_len, ret_addr)
            else if (buf.len > threshold and new_len > threshold)
                self.large_allocator.resize(buf, log2_buf_align, new_len, ret_addr)
            else
                false;
        }

        pub fn free(self: *Self, buf: []u8, log2_buf_align: u8, ret_addr: usize) void {
            if (buf.len <= threshold) {
                self.small_allocator.free(buf, log2_buf_align, ret_addr);
            } else {
                self.large_allocator.free(buf, log2_buf_align, ret_addr);
            }
        }

        pub usingnamespace if (helpers.hasInit2(SmallAllocator, LargeAllocator)) struct {
            pub const init = helpers.init2(
                Self,
                "small_allocator",
                SmallAllocator,
                "large_allocator",
                LargeAllocator,
            );
        } else struct {};

        pub usingnamespace if (helpers.hasDefaultInit2(SmallAllocator, LargeAllocator)) struct {
            pub const default_init = helpers.defaultInit2(
                Self,
                "small_allocator",
                SmallAllocator,
                "large_allocator",
                LargeAllocator,
            );
        } else struct {};

        pub usingnamespace if (helpers.hasInitInPlace2(SmallAllocator, LargeAllocator)) struct {
            pub const initInPlace = helpers.initInPlace2(
                Self,
                "small_allocator",
                SmallAllocator,
                "large_allocator",
                LargeAllocator,
            );
        } else struct {};

        pub usingnamespace if (helpers.hasInitExtra2(SmallAllocator, LargeAllocator)) struct {
            pub const initExtra = helpers.initExtra2(
                Self,
                "small_allocator",
                SmallAllocator,
                "large_allocator",
                LargeAllocator,
            );
        } else struct {};

        pub usingnamespace if (helpers.hasInitInPlaceExtra2(SmallAllocator, LargeAllocator)) struct {
            pub const initInPlaceExtra = helpers.initInPlaceExtra2(
                Self,
                "small_allocator",
                SmallAllocator,
                "large_allocator",
                LargeAllocator,
            );
        } else struct {};

        pub usingnamespace if (@hasDecl(SmallAllocator, "owns") and @hasDecl(LargeAllocator, "owns")) struct {
            pub fn owns(self: *Self, buf: []u8) bool {
                return if (buf.len <= threshold)
                    self.small_allocator.owns(buf)
                else
                    self.large_allocator.owns(buf);
            }
        } else struct {};

        pub usingnamespace if (@hasDecl(SmallAllocator, "freeAll") and @hasDecl(LargeAllocator, "freeAll")) struct {
            pub fn freeAll(self: *Self) void {
                self.small_allocator.freeAll();
                self.large_allocator.freeAll();
            }
        } else struct {};
    };
}

test {
    const StackFallback = Fallback(Stack(1024), Std);
    const StackSegregatedFallback = Fallback(
        Stack(1024),
        Segregated(
            FreeList(FixedBuffer, 64, 2, null),
            Std,
            64,
        ),
    );
    comptime {
        validateAllocator(Null);
        validateAllocator(FixedBuffer);
        validateAllocator(StackFallback);
        validateAllocator(StackSegregatedFallback);
    }
    std.testing.refAllDecls(@This());
    std.testing.refAllDecls(Fallback(FixedBuffer, Null));
    std.testing.refAllDecls(Stack(1024));
    std.testing.refAllDecls(FreeList(Stack(1024), 64, 1, null));
    std.testing.refAllDecls(FreeList(Stack(1024), 8, 1, 32));
    std.testing.refAllDecls(StackFallback);
    std.testing.refAllDecls(StackSegregatedFallback);

    var test_allocator: Fallback(Stack(1024), Std) = undefined;
    test_allocator.initInPlaceExtra(.{std.testing.allocator});
    const a = allocator(&test_allocator);

    try std.heap.testAllocator(a); // the first realloc makes the test fail
    try std.heap.testAllocatorAligned(a);
    try std.heap.testAllocatorAlignedShrink(a);
    try std.heap.testAllocatorLargeAlignment(a);
}
