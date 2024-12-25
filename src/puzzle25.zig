const std = @import("std");
pub const utils = @import("utils.zig");
pub const print = utils.print;
const alloc = std.heap.page_allocator;

const Task = enum { one, two };
const DataSource = enum { sample, real };
const task: Task = .one;
const source: DataSource = .real;

const verbose: bool = switch (source) {
    .sample => true,
    .real => false,
};

const filename: []const u8 = switch (source) {
    .sample => "puzzle25.data.sample",
    .real => "puzzle25.data",
};

pub fn puzzle() !void {
    var points = std.ArrayList(Point).init(alloc);
    // defer points.deinit();

    var keys = std.ArrayList(Key).init(alloc);
    defer keys.deinit();

    var locks = std.ArrayList(Lock).init(alloc);
    defer locks.deinit();

    const file = @embedFile(filename);
    const split = std.mem.split;
    var splits = split(u8, file, "\n");
    var x: i64 = 0;
    var y: i64 = 0;
    var width: i64 = 0;
    var height: i64 = 0;
    while (splits.next()) |line| {
        if (line.len == 0) {
            height = y;

            var map = Map{ .width = width, .height = height, .bwidth = width - 1, .bheight = height - 1, .points = points };
            if (try map.getKey()) |key| try keys.append(key);
            if (try map.getLock()) |lock| try locks.append(lock);
            points.clearAndFree();

            y = 0;
            continue;
        }
        x = 0;
        for (line) |c| {
            const p = Point{ .x = x, .y = y, .label = c };
            try points.append(p);
            x += 1;
        }
        width = x;
        y += 1;
    }

    for (keys.items) |key| {
        print("Key: {any}", .{key});
    }

    for (locks.items) |lock| {
        print("Lock: {any}", .{lock});
    }

    var fits: i64 = 0;
    for (keys.items) |key| {
        for (locks.items) |lock| {
            if (key.fitsIn(lock)) fits += 1;
        }
    }

    print("The number of keys that fits the locks: {d}", .{fits});
}

const Lock = struct {
    heights: []i64,
    depth: i64,
};

const Key = struct {
    heights: []i64,

    fn fitsIn(self: Key, lock: Lock) bool {
        for (0..self.heights.len) |i| {
            const k = self.heights[i];
            const l = lock.heights[i];
            const t = l + k;
            if (t >= lock.depth) return false;
        }
        return true;
    }
};

const Point = struct {
    x: i64,
    y: i64,
    label: u8,
};

const Map = struct {
    width: i64,
    height: i64,
    bwidth: i64,
    bheight: i64,
    points: std.ArrayList(Point),

    fn getPointIndex(self: *Map, x: i64, y: i64) usize {
        return @intCast(y * self.width + x);
    }

    fn getPoint(self: *Map, x: i64, y: i64) Point {
        return self.points[self.getPointIndex(x, y)];
    }

    fn getKey(self: *Map) !?Key {
        var bottomFilled = true;
        for (0..@intCast(self.width)) |i| {
            if (self.points.items[self.getPointIndex(@intCast(i), self.bheight)].label != '#') bottomFilled = false;
        }
        if (bottomFilled) {
            var heights: std.ArrayList(i64) = std.ArrayList(i64).init(alloc);
            for (0..@intCast(self.width)) |x| {
                var h: i64 = 0;
                for (0..@intCast(self.bheight)) |yt| {
                    const ytt: i64 = @intCast(yt);
                    const y = self.bheight - ytt - 1;
                    if (self.points.items[self.getPointIndex(@intCast(x), y)].label == '#') h += 1;
                }
                try heights.append(h);
            }
            return Key{ .heights = heights.items };
        }
        return null;
    }

    fn getLock(self: *Map) !?Lock {
        var topFilled = true;
        for (0..@intCast(self.width)) |i| {
            if (self.points.items[i].label != '#') topFilled = false;
        }
        if (topFilled) {
            var heights: std.ArrayList(i64) = std.ArrayList(i64).init(alloc);
            for (0..@intCast(self.width)) |x| {
                var h: i64 = 0;
                for (1..@intCast(self.bheight)) |y| {
                    if (self.points.items[self.getPointIndex(@intCast(x), @intCast(y))].label == '#') h += 1;
                }
                try heights.append(h);
            }
            return Lock{ .heights = heights.items, .depth = self.bheight };
        }
        return null;
    }
};
