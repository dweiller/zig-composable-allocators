const std = @import("std");

const assert = std.debug.assert;

// discard the first param of a function so we transform Fn(*T, A, B, C) D -> Fn(A, B, C) D
pub fn ArgsIIPE(comptime Function: type) type {
    const info = @typeInfo(Function);
    var modified_type_info = info;
    modified_type_info.Fn.params = info.Fn.params[1..];
    std.meta.ArgsTuple(@Type(modified_type_info));
}

pub fn hasInit2(
    comptime Allocator1: type,
    comptime Allocator2: type,
) bool {
    return (@hasDecl(Allocator1, "init") and @hasDecl(Allocator2, "init")) or
        (@hasDecl(Allocator1, "init") and @hasDecl(Allocator2, "default_init")) or
        (@hasDecl(Allocator1, "default_init") and @hasDecl(Allocator2, "init"));
}

pub fn init2(
    comptime Self: type,
    comptime field_1: []const u8,
    comptime Allocator1: type,
    comptime field_2: []const u8,
    comptime Allocator2: type,
) fn () Self {
    comptime assert(hasInit2(Allocator1, Allocator2));
    return
    // init() Self
    if (@hasDecl(Allocator1, "init") and @hasDecl(Allocator2, "init")) struct {
        pub fn init() Self {
            var self: Self = undefined;
            @field(self, field_1) = Allocator1.init();
            @field(self, field_2) = Allocator2.init();
            return self;
        }
    }.init else if (@hasDecl(Allocator1, "init") and @hasDecl(Allocator2, "default_init")) struct {
        pub fn init() Self {
            var self: Self = undefined;
            @field(self, field_1) = Allocator1.init();
            @field(self, field_2) = Allocator2.default_init;
            return self;
        }
    }.init else if (@hasDecl(Allocator1, "default_init") and @hasDecl(Allocator2, "init")) struct {
        pub fn init() Self {
            var self: Self = undefined;
            @field(self, field_1) = Allocator1.default_init;
            @field(self, field_2) = Allocator2.init();
            return self;
        }
    }.init else unreachable;
}

pub fn hasDefaultInit2(
    comptime Allocator1: type,
    comptime Allocator2: type,
) bool {
    return (@hasDecl(Allocator1, "default_init") and @hasDecl(Allocator2, "default_init"));
}

pub fn defaultInit2(
    comptime Self: type,
    comptime field_1: []const u8,
    comptime Allocator1: type,
    comptime field_2: []const u8,
    comptime Allocator2: type,
) Self {
    comptime var self: Self = undefined;
    @field(self, field_1) = Allocator1.default_init;
    @field(self, field_2) = Allocator2.default_init;
    return self;
}

pub fn hasInitInPlace2(
    comptime Allocator1: type,
    comptime Allocator2: type,
) bool {
    return (@hasDecl(Allocator1, "initInPlace") and @hasDecl(Allocator2, "initInPlace")) or
        (@hasDecl(Allocator1, "initInPlace") and @hasDecl(Allocator2, "init")) or
        (@hasDecl(Allocator1, "init") and @hasDecl(Allocator2, "initInPlace")) or
        (@hasDecl(Allocator1, "initInPlace") and @hasDecl(Allocator2, "default_init")) or
        (@hasDecl(Allocator1, "default_init") and @hasDecl(Allocator2, "initInPlace"));
}

pub fn InitInPlace2(
    comptime Self: type,
    comptime Allocator1: type,
    comptime Allocator2: type,
) type {
    assert(hasInitInPlace2(Allocator1, Allocator2));
    return if (@hasDecl(Allocator1, "initInPlace") and @hasDecl(Allocator2, "initInPlace"))
        fn (self: *Self) void
    else if (@hasDecl(Allocator1, "initInPlace") and @hasDecl(Allocator2, "init"))
        fn (self: *Self) void
    else if (@hasDecl(Allocator1, "init") and @hasDecl(Allocator2, "initInPlace"))
        fn (self: *Self) void
    else if (@hasDecl(Allocator1, "initInPlace") and @hasDecl(Allocator2, "default_init"))
        fn (self: *Self) void
    else if (@hasDecl(Allocator1, "default_init") and @hasDecl(Allocator2, "initInPlace"))
        fn (self: *Self) void
    else
        unreachable;
}

pub fn initInPlace2(
    comptime Self: type,
    comptime field_1: []const u8,
    comptime Allocator1: type,
    comptime field_2: []const u8,
    comptime Allocator2: type,
) InitInPlace2(Self, Allocator1, Allocator2) {
    return if (@hasDecl(Allocator1, "initInPlace") and @hasDecl(Allocator2, "initInPlace")) struct {
        pub fn initInPlace(self: *Self) void {
            @field(self, field_1).initInPlace();
            @field(self, field_2).initInPlace();
        }
    } else if (@hasDecl(Allocator1, "initInPlace") and @hasDecl(Allocator2, "init")) struct {
        pub fn initInPlace(self: *Self) void {
            @field(self, field_1).initInPlace();
            @field(self, field_2) = Allocator2.init();
        }
    } else if (@hasDecl(Allocator1, "init") and @hasDecl(Allocator2, "initInPlace")) struct {
        pub fn initInPlace(self: *Self) void {
            @field(self, field_1) = Allocator1.init();
            @field(self, field_2).initInPlace();
        }
    } else if (@hasDecl(Allocator1, "initInPlace") and @hasDecl(Allocator2, "default_init")) struct {
        pub fn initInPlace(self: *Self) void {
            @field(self, field_1).initInPlace();
            @field(self, field_2) = Allocator2.default_init;
        }
    } else if (@hasDecl(Allocator1, "default_init") and @hasDecl(Allocator2, "initInPlace")) struct {
        pub fn initInPlace(self: *Self) void {
            @field(self, field_1) = Allocator1.default_init;
            @field(self, field_2).initInPlace();
        }
    } else unreachable;
}

pub fn hasInitExtra2(
    comptime Allocator1: type,
    comptime Allocator2: type,
) bool {
    return (@hasDecl(Allocator1, "initExtra") and @hasDecl(Allocator2, "init")) or
        (@hasDecl(Allocator1, "init") and @hasDecl(Allocator2, "initExtra")) or
        (@hasDecl(Allocator1, "initExtra") and @hasDecl(Allocator2, "initExtra")) or
        (@hasDecl(Allocator1, "initExtra") and @hasDecl(Allocator2, "default_init")) or
        (@hasDecl(Allocator1, "default_init") and @hasDecl(Allocator2, "initExtra"));
}

pub fn InitExtra2(
    comptime Self: type,
    comptime Allocator1: type,
    comptime Allocator2: type,
) type {
    comptime assert(hasInitExtra2(Allocator1, Allocator2));
    return if (@hasDecl(Allocator1, "initExtra") and @hasDecl(Allocator2, "init"))
        fn (args: std.meta.ArgsTuple(@TypeOf(Allocator1.initExtra))) Self
    else if (@hasDecl(Allocator1, "init") and @hasDecl(Allocator2, "initExtra"))
        fn (args: std.meta.ArgsTuple(@TypeOf(Allocator2.initExtra))) Self
    else if (@hasDecl(Allocator1, "initExtra") and @hasDecl(Allocator2, "initExtra"))
        fn (
            args1: std.meta.ArgsTuple(@TypeOf(Allocator1.initExtra)),
            args2: std.meta.ArgsTuple(@TypeOf(Allocator2.initExtra)),
        ) Self
    else if (@hasDecl(Allocator1, "initExtra") and @hasDecl(Allocator2, "default_init"))
        fn (args: std.meta.ArgsTuple(@TypeOf(Allocator1.initExtra))) Self
    else if (@hasDecl(Allocator1, "default_init") and @hasDecl(Allocator2, "initExtra"))
        fn (args: std.meta.ArgsTuple(@TypeOf(Allocator2.initExtra))) Self
    else
        unreachable;
}

pub fn initExtra2(
    comptime Self: type,
    comptime field_1: []const u8,
    comptime Allocator1: type,
    comptime field_2: []const u8,
    comptime Allocator2: type,
) InitExtra2(Self, Allocator1, Allocator2) {
    return if (@hasDecl(Allocator1, "initExtra") and @hasDecl(Allocator2, "init")) struct {
        pub fn initExtra(args: std.meta.ArgsTuple(@TypeOf(Allocator1.initExtra))) Self {
            var self: Self = undefined;
            @field(self, field_1) = @call(.auto, Allocator1.initExtra, args);
            @field(self, field_2) = Allocator2.init();
            return self;
        }
    }.initExtra else if (@hasDecl(Allocator1, "init") and @hasDecl(Allocator2, "initExtra")) struct {
        pub fn initExtra(args: std.meta.ArgsTuple(@TypeOf(Allocator2.initExtra))) Self {
            var self: Self = undefined;
            @field(self, field_1) = Allocator1.init();
            @field(self, field_2) = @call(.auto, Allocator2.initExtra, args);
            return self;
        }
    }.initExtra else if (@hasDecl(Allocator1, "initExtra") and @hasDecl(Allocator2, "initExtra")) struct {
        pub fn initExtra(
            args1: std.meta.ArgsTuple(@TypeOf(Allocator1.initExtra)),
            args2: std.meta.ArgsTuple(@TypeOf(Allocator2.initExtra)),
        ) Self {
            var self: Self = undefined;
            @field(self, field_1) = @call(.auto, Allocator1.initExtra, args1);
            @field(self, field_2) = @call(.auto, Allocator2.initExtra, args2);
            return self;
        }
    }.initExtra else if (@hasDecl(Allocator1, "initExtra") and @hasDecl(Allocator2, "default_init")) struct {
        pub fn initExtra(args: std.meta.ArgsTuple(@TypeOf(Allocator1.initExtra))) Self {
            var self: Self = undefined;
            @field(self, field_1) = @call(.auto, Allocator1.initExtra, args);
            @field(self, field_2) = Allocator2.default_init;
            return self;
        }
    }.initExtra else if (@hasDecl(Allocator1, "default_init") and @hasDecl(Allocator2, "initExtra")) struct {
        pub fn initExtra(args: std.meta.ArgsTuple(@TypeOf(Allocator2.initExtra))) Self {
            var self: Self = undefined;
            @field(self, field_1) = Allocator1.default_init;
            @field(self, field_2) = @call(.auto, Allocator2.initExtra, args);
            return self;
        }
    } else unreachable;
}

pub fn hasInitInPlaceExtra2(
    comptime Allocator1: type,
    comptime Allocator2: type,
) bool {
    return (@hasDecl(Allocator1, "initInPlaceExtra") and @hasDecl(Allocator2, "initInPlaceExtra")) or (@hasDecl(Allocator1, "initInPlaceExtra") and @hasDecl(Allocator2, "initExtra")) or (@hasDecl(Allocator1, "initExtra") and @hasDecl(Allocator2, "initInPlaceExtra")) or (@hasDecl(Allocator1, "initInPlaceExtra") and @hasDecl(Allocator2, "init")) or (@hasDecl(Allocator1, "init") and @hasDecl(Allocator2, "initInPlaceExtra")) or (@hasDecl(Allocator1, "initInPlaceExtra") and @hasDecl(Allocator2, "default_init")) or (@hasDecl(Allocator1, "default_init") and @hasDecl(Allocator2, "initInPlaceExtra")) or (@hasDecl(Allocator1, "initInPlaceExtra") and @hasDecl(Allocator2, "initInPlace")) or (@hasDecl(Allocator1, "initInPlace") and @hasDecl(Allocator2, "initInPlaceExtra")) or (@hasDecl(Allocator1, "initExtra") and @hasDecl(Allocator2, "initInPlace")) or (@hasDecl(Allocator1, "initInPlace") and @hasDecl(Allocator2, "initExtra"));
}

pub fn InitInPlaceExtra2(
    comptime Self: type,
    comptime Allocator1: type,
    comptime Allocator2: type,
) type {
    assert(hasInitInPlaceExtra2(Allocator1, Allocator2));
    return if (@hasDecl(Allocator1, "initInPlaceExtra") and @hasDecl(Allocator2, "initInPlaceExtra"))
        fn (
            self: *Self,
            args1: ArgsIIPE(@TypeOf(Allocator1.initInPlaceExtra)),
            args2: ArgsIIPE(@TypeOf(Allocator2.initInPlaceExtra)),
        ) void
    else if (@hasDecl(Allocator1, "initInPlaceExtra") and @hasDecl(Allocator2, "initExtra"))
        fn (
            self: *Self,
            args1: ArgsIIPE(@TypeOf(Allocator1.initInPlaceExtra)),
            args2: std.meta.ArgsTuple(@TypeOf(Allocator2.initExtra)),
        ) void
    else if (@hasDecl(Allocator1, "initExtra") and @hasDecl(Allocator2, "initInPlaceExtra"))
        fn (
            self: *Self,
            args1: std.meta.ArgsTuple(@TypeOf(Allocator1.initExtra)),
            args2: ArgsIIPE(@TypeOf(Allocator2.initInPlaceExtra)),
        ) void
    else if (@hasDecl(Allocator1, "initInPlaceExtra") and @hasDecl(Allocator2, "init"))
        fn (
            self: *Self,
            args1: ArgsIIPE(@TypeOf(Allocator1.initInPlaceExtra)),
        ) void
    else if (@hasDecl(Allocator1, "init") and @hasDecl(Allocator2, "initInPlaceExtra"))
        fn (
            self: *Self,
            args2: ArgsIIPE(@TypeOf(Allocator2.initInPlaceExtra)),
        ) void
    else if (@hasDecl(Allocator1, "initInPlaceExtra") and @hasDecl(Allocator2, "default_init"))
        fn (
            self: *Self,
            args1: ArgsIIPE(@TypeOf(Allocator1.initInPlaceExtra)),
        ) void
    else if (@hasDecl(Allocator1, "default_init") and @hasDecl(Allocator2, "initInPlaceExtra"))
        fn (
            self: *Self,
            args2: ArgsIIPE(@TypeOf(Allocator2.initInPlaceExtra)),
        ) void
    else if (@hasDecl(Allocator1, "initInPlaceExtra") and @hasDecl(Allocator2, "initInPlace"))
        fn (
            self: *Self,
            args1: ArgsIIPE(@TypeOf(Allocator1.initInPlaceExtra)),
        ) void
    else if (@hasDecl(Allocator1, "initInPlace") and @hasDecl(Allocator2, "initInPlaceExtra"))
        fn (
            self: *Self,
            args2: ArgsIIPE(@TypeOf(Allocator2.initInPlaceExtra)),
        ) void
    else if (@hasDecl(Allocator1, "initExtra") and @hasDecl(Allocator2, "initInPlace"))
        fn (
            self: *Self,
            args1: std.meta.ArgsTuple(@TypeOf(Allocator1.initExtra)),
        ) void
    else if (@hasDecl(Allocator1, "initInPlace") and @hasDecl(Allocator2, "initExtra"))
        fn (
            self: *Self,
            args2: std.meta.ArgsTuple(@TypeOf(Allocator2.initExtra)),
        ) void
    else
        unreachable;
}

pub fn initInPlaceExtra2(
    comptime Self: type,
    comptime field_1: []const u8,
    comptime Allocator1: type,
    comptime field_2: []const u8,
    comptime Allocator2: type,
) InitInPlaceExtra2(Self, Allocator1, Allocator2) {
    // initInPlaceExtra(*Self, ...) void
    return if (@hasDecl(Allocator1, "initInPlaceExtra") and @hasDecl(Allocator2, "initInPlaceExtra")) struct {
        pub fn initInPlaceExtra(
            self: *Self,
            args1: ArgsIIPE(@TypeOf(Allocator1.initInPlaceExtra)),
            args2: ArgsIIPE(@TypeOf(Allocator2.initInPlaceExtra)),
        ) void {
            @call(.auto, Allocator1.initInPlaceExtra, .{&@field(self, field_1)} ++ args1);
            @call(.auto, Allocator2.initInPlaceExtra, .{&@field(self, field_2)} ++ args2);
        }
    }.initInPlaceExtra else if (@hasDecl(Allocator1, "initInPlaceExtra") and @hasDecl(Allocator2, "initExtra")) struct {
        pub fn initInPlaceExtra(
            self: *Self,
            args1: ArgsIIPE(@TypeOf(Allocator1.initInPlaceExtra)),
            args2: std.meta.ArgsTuple(@TypeOf(Allocator2.initExtra)),
        ) void {
            @call(.auto, Allocator1.initInPlaceExtra, .{&@field(self, field_1)} ++ args1);
            @field(self, field_2) = @call(.auto, Allocator2.initExtra, args2);
        }
    }.initInPlaceExtra else if (@hasDecl(Allocator1, "initExtra") and @hasDecl(Allocator2, "initInPlaceExtra")) struct {
        pub fn initInPlaceExtra(
            self: *Self,
            args1: std.meta.ArgsTuple(@TypeOf(Allocator1.initExtra)),
            args2: ArgsIIPE(@TypeOf(Allocator2.initInPlaceExtra)),
        ) void {
            @field(self, field_1) = @call(.auto, Allocator1.initExtra, args2);
            @call(.auto, Allocator2.initInPlaceExtra, .{&@field(self, field_2)} ++ args1);
        }
    }.initInPlaceExtra else if (@hasDecl(Allocator1, "initInPlaceExtra") and @hasDecl(Allocator2, "init")) struct {
        pub fn initInPlaceExtra(
            self: *Self,
            args1: ArgsIIPE(@TypeOf(Allocator1.initInPlaceExtra)),
        ) void {
            @call(.auto, Allocator1.initInPlaceExtra, .{&@field(self, field_1)} ++ args1);
            @field(self, field_2) = Allocator2.init();
        }
    }.initInPlaceExtra else if (@hasDecl(Allocator1, "init") and @hasDecl(Allocator2, "initInPlaceExtra")) struct {
        pub fn initInPlaceExtra(
            self: *Self,
            args2: ArgsIIPE(@TypeOf(Allocator2.initInPlaceExtra)),
        ) void {
            @field(self, field_1) = Allocator1.init();
            @call(.auto, Allocator2.initInPlaceExtra, .{&@field(self, field_2)} ++ args2);
        }
    }.initInPlaceExtra else if (@hasDecl(Allocator1, "initInPlaceExtra") and @hasDecl(Allocator2, "default_init")) struct {
        pub fn initInPlaceExtra(
            self: *Self,
            args1: ArgsIIPE(@TypeOf(Allocator1.initInPlaceExtra)),
        ) void {
            @call(.auto, Allocator1.initInPlaceExtra, .{&@field(self, field_1)} ++ args1);
            @field(self, field_2) = Allocator2.default_init;
        }
    }.initInPlaceExtra else if (@hasDecl(Allocator1, "default_init") and @hasDecl(Allocator2, "initInPlaceExtra")) struct {
        pub fn initInPlaceExtra(
            self: *Self,
            args2: ArgsIIPE(@TypeOf(Allocator2.initInPlaceExtra)),
        ) void {
            @field(self, field_1) = Allocator1.default_init;
            @call(.auto, Allocator2.initInPlaceExtra, .{&@field(self, field_2)} ++ args2);
        }
    }.initInPlaceExtra else if (@hasDecl(Allocator1, "initInPlaceExtra") and @hasDecl(Allocator2, "initInPlace")) struct {
        pub fn initInPlaceExtra(
            self: *Self,
            args1: ArgsIIPE(@TypeOf(Allocator1.initInPlaceExtra)),
        ) void {
            @call(.auto, Allocator1.initInPlaceExtra, .{&@field(self, field_1)} ++ args1);
            @field(self, field_2).initInPlace();
        }
    }.initInPlaceExtra else if (@hasDecl(Allocator1, "initInPlace") and @hasDecl(Allocator2, "initInPlaceExtra")) struct {
        pub fn initInPlaceExtra(
            self: *Self,
            args2: ArgsIIPE(@TypeOf(Allocator2.initInPlaceExtra)),
        ) void {
            @field(self, field_1).initInPlace();
            @call(.auto, Allocator2.initInPlaceExtra, .{&@field(self, field_2)} ++ args2);
        }
    }.initInPlaceExtra else if (@hasDecl(Allocator1, "initExtra") and @hasDecl(Allocator2, "initInPlace")) struct {
        pub fn initInPlaceExtra(
            self: *Self,
            args1: std.meta.ArgsTuple(@TypeOf(Allocator1.initExtra)),
        ) void {
            @field(self, field_1) = @call(.auto, Allocator1.initExtra, args1);
            @field(self, field_2).initInPlace();
        }
    }.initInPlaceExtra else if (@hasDecl(Allocator1, "initInPlace") and @hasDecl(Allocator2, "initExtra")) struct {
        pub fn initInPlaceExtra(
            self: *Self,
            args2: std.meta.ArgsTuple(@TypeOf(Allocator2.initExtra)),
        ) void {
            @field(self, field_1).initInPlace();
            @field(self, field_2) = @call(.auto, Allocator2.initExtra, args2);
        }
    }.initInPlaceExtra else unreachable;
}
