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
