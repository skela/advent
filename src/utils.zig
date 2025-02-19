const std = @import("std");

pub fn print(comptime fmt: []const u8, args: anytype) void {
    std.debug.print(fmt ++ "\n", args);
}

pub fn print_raw(comptime fmt: []const u8, args: anytype) void {
    std.debug.print(fmt, args);
}

pub fn print_s(comptime fmt: []const u8) void {
    std.debug.print(fmt, .{});
}

pub fn parsei64(input: []const u8) !i64 {
    return try std.fmt.parseInt(i64, input, 10);
}

pub fn parseu64(input: []const u8) !u64 {
    return try std.fmt.parseInt(u64, input, 10);
}

pub fn parsei32(input: []const u8) !i32 {
    return try std.fmt.parseInt(i32, input, 10);
}

pub fn parseusize(input: []const u8) !usize {
    return try std.fmt.parseInt(usize, input, 10);
}

pub fn isStringEqual(a: ?[]const u8, b: ?[]const u8) bool {
    if (a) |aa| {
        if (b) |bb| {
            if (aa.len != bb.len) return false;
            for (0..aa.len) |i| {
                if (aa[i] != bb[i]) return false;
            }
            return true;
        }
    }
    return false;
}
