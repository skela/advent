const std = @import("std");
pub const print = @import("utils.zig").print;

const Task = enum { one, two };
const task: Task = Task.two;
const sample: bool = false;
const verbose: bool = false;

pub fn puzzle() !void {
    var robots = std.ArrayList(Robot).init(std.heap.page_allocator);
    defer robots.deinit();
    var counts = std.ArrayList(Count).init(std.heap.page_allocator);
    defer counts.deinit();

    const file = @embedFile(if (sample) "puzzle14.data.sample" else "puzzle14.data");
    const split = std.mem.split;
    var splits = split(u8, file, "\n");
    while (splits.next()) |line| {
        if (line.len == 0) {
            continue;
        }
        const p_x = std.mem.indexOf(u8, line, "p");
        const p_c = std.mem.indexOf(u8, line, ",");
        const p_s = std.mem.indexOf(u8, line, " ");
        const p_xi = if (p_x) |i| i else 0;
        const p_ci = if (p_c) |i| i else 0;
        const p_si = if (p_s) |i| i else 0;
        const px = try parseNumber(line[p_xi + 2 .. p_ci]);
        const py = try parseNumber(line[p_ci + 1 .. p_si]);
        const rem = line[p_si..];
        const v_x = std.mem.indexOf(u8, rem, "v");
        const v_c = std.mem.indexOf(u8, rem, ",");
        const v_xi = if (v_x) |i| i else 0;
        const v_ci = if (v_c) |i| i else 0;
        const vx = try parseNumber(rem[v_xi + 2 .. v_ci]);
        const vy = try parseNumber(rem[v_ci + 1 ..]);
        const p = Point{ .x = px, .y = py };
        const v = Velocity{ .dx = vx, .dy = vy };
        const r = Robot{ .p = p, .v = v };
        try robots.append(r);
    }

    // const p = Point{ .x = 2, .y = 4 };
    // const v = Velocity{ .dx = 2, .dy = -3 };
    // const r0 = Robot{ .p = p, .v = v };
    // try robots.append(r0);

    const width: i64 = 101;
    const height: i64 = 103;
    // const width: i64 = 11;
    // const height: i64 = 7;

    for (0..height) |y| {
        for (0..width) |x| {
            try counts.append(Count{ .numberOfRobots = 0, .p = Point{ .x = @intCast(x), .y = @intCast(y) } });
        }
    }

    const map = Map{ .width = width, .height = height, .bwidth = width - 1, .bheight = height - 1 };
    var ctx = Context{ .map = map, .counts = counts.items, .robots = robots };

    if (verbose) {
        print("Found {d} robots", .{robots.items.len});

        for (robots.items) |r| {
            print("Robot at {d},{d} with velocity {d},{d}", .{ r.p.x, r.p.y, r.v.dx, r.v.dy });
        }
    }

    ctx.init();
    if (verbose) {
        print("Initial state", .{});
        ctx.printMap();
    }

    const seconds: usize = switch (task) {
        .one => 100,
        .two => 10000,
    };

    for (0..seconds) |i| {
        if (verbose) {
            print("Tick {d}", .{i + 1});
        }
        ctx.tick();
        if (verbose) {
            ctx.printMap();
            print("-------------", .{});
        }
        if (task == .two) {
            ctx.printMapIfInteresting(i + 1);
        }
    }

    if (task == .one) {
        var q1: i64 = 0;
        var q2: i64 = 0;
        var q3: i64 = 0;
        var q4: i64 = 0;
        const hw = @divExact(ctx.map.bwidth, 2);
        const hh = @divExact(ctx.map.bheight, 2);
        for (ctx.counts) |c| {
            if (c.p.x < hw and c.p.y < hh) {
                q1 += c.numberOfRobots;
            }
            if (c.p.x > hw and c.p.y < hh) {
                q2 += c.numberOfRobots;
            }
            if (c.p.x < hw and c.p.y > hh) {
                q3 += c.numberOfRobots;
            }
            if (c.p.x > hw and c.p.y > hh) {
                q4 += c.numberOfRobots;
            }
        }

        const safetyFactor = q1 * q2 * q3 * q4;
        print("Safety factor is {d}", .{safetyFactor});
    }
}

fn parseNumber(input: []const u8) !i64 {
    return try std.fmt.parseInt(i64, input, 10);
}

const Robot = struct {
    p: Point,
    v: Velocity,
};

const Count = struct {
    p: Point,
    numberOfRobots: i64,
};

const Point = struct {
    x: i64,
    y: i64,
};

const Velocity = struct {
    dx: i64,
    dy: i64,
};

const Map = struct {
    width: i64,
    height: i64,
    bwidth: i64,
    bheight: i64,
};

const Context = struct {
    map: Map,
    robots: std.ArrayList(Robot),
    counts: []Count,

    fn getPoint(self: *Context, x: i64, y: i64) Point {
        var rx: i64 = x;
        var ry: i64 = y;
        if (rx < 0) {
            rx = self.map.width + rx;
        } else if (rx >= self.map.width) {
            rx = rx - self.map.width;
        }
        if (ry < 0) {
            ry = self.map.height + ry;
        } else if (ry >= self.map.height) {
            ry = ry - self.map.height;
        }
        return Point{ .x = rx, .y = ry };
    }

    fn getIndex(self: *Context, x: i64, y: i64) usize {
        const p = self.getPoint(x, y);
        // print("Getting index for {d},{d}", .{ p.x, p.y });
        return @intCast(p.y * self.map.width + p.x);
    }

    fn getCount(self: *Context, x: i64, y: i64) i64 {
        return self.map.points[getIndex(self, x, y)];
    }

    fn printMap(self: *Context) void {
        for (self.counts) |c| {
            if (c.numberOfRobots == 0) {
                std.debug.print(".", .{});
            } else {
                std.debug.print("{d}", .{c.numberOfRobots});
            }
            if (c.p.x == self.map.bwidth) {
                std.debug.print("\n", .{});
            }
        }
        print("\n", .{});
    }

    fn printMapIfInteresting(self: *Context, second: usize) void {
        var interesting: i64 = 0;
        const interestFactor: i64 = 8;
        for (self.counts) |c| {
            if (c.numberOfRobots == 0) {
                interesting = 0;
            } else {
                interesting += 1;
            }
            if (interesting > interestFactor) {
                break;
            }
        }

        if (interesting < interestFactor) {
            return;
        }
        for (self.counts) |c| {
            if (c.numberOfRobots == 0) {
                std.debug.print(" ", .{});
            } else {
                std.debug.print("#", .{});
            }
            if (c.p.x == self.map.bwidth) {
                std.debug.print("\n", .{});
            }
        }
        print("\n", .{});
        print("Seconds {d}", .{second});
    }

    fn init(self: *Context) void {
        for (self.robots.items) |r| {
            const index = self.getIndex(r.p.x, r.p.y);
            self.counts[index].numberOfRobots = self.counts[index].numberOfRobots + 1;
        }
    }

    fn tick(self: *Context) void {
        for (0..self.robots.items.len) |ri| {
            const r = self.robots.items[ri];
            const index_start = self.getIndex(r.p.x, r.p.y);
            const end_point = self.getPoint(r.p.x + r.v.dx, r.p.y + r.v.dy);
            const index_end = self.getIndex(end_point.x, end_point.y);
            self.robots.items[ri].p = end_point;
            self.counts[index_start].numberOfRobots = if (self.counts[index_start].numberOfRobots == 1) 0 else self.counts[index_start].numberOfRobots - 1;
            self.counts[index_end].numberOfRobots = self.counts[index_end].numberOfRobots + 1;
        }
    }
};
