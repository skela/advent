const std = @import("std");
pub const print = @import("utils.zig").print;
const deq = @import("deque.zig");

const Task = enum { one, two };
const DataSource = enum { sample, real };
const task: Task = .one;
const source: DataSource = .real;

const verbose: bool = switch (source) {
    .sample => true,
    .real => false,
};

const filename: []const u8 = switch (source) {
    .sample => "puzzle19.data.sample",
    .real => "puzzle19.data",
};

pub fn puzzle() !void {
    var patterns = std.ArrayList(Pattern).init(std.heap.page_allocator);
    defer patterns.deinit();

    var designs = std.ArrayList(Design).init(std.heap.page_allocator);
    defer designs.deinit();

    var numberOfDesigns = std.StringHashMap(u64).init(std.heap.page_allocator);
    defer numberOfDesigns.deinit();

    const file = @embedFile(filename);
    const split = std.mem.split;
    var splits = split(u8, file, "\n");
    var index: usize = 0;
    while (splits.next()) |line| {
        if (line.len == 0) {
            continue;
        }

        if (index == 0) {
            var comb = split(u8, line, ",");
            while (comb.next()) |c| {
                var cleanup = std.ArrayList(u8).init(std.heap.page_allocator);
                for (c) |s| {
                    if (s != ' ') {
                        try cleanup.append(s);
                    }
                }
                try patterns.append(Pattern{ .pattern = cleanup.items });
            }
        } else {
            try designs.append(Design{ .pattern = line });
        }

        index += 1;
    }

    var ctx = Context{ .designs = designs.items, .patterns = patterns.items, .numberOfDesigns = numberOfDesigns };

    ctx.printShit();

    try ctx.checkDesigns();
}

const Design = struct {
    pattern: []const u8,

    fn startsWith(self: Design, pattern: Pattern) bool {
        if (self.pattern.len < pattern.pattern.len) {
            return false;
        }
        for (0..pattern.pattern.len) |i| {
            if (self.pattern[i] != pattern.pattern[i]) {
                return false;
            }
        }
        return true;
    }

    fn removePrefix(self: Design, pattern: Pattern) Design {
        return Design{ .pattern = self.pattern[pattern.pattern.len..] };
    }
};

const Pattern = struct {
    pattern: []const u8,
};

const Context = struct {
    designs: []Design,
    patterns: []Pattern,
    numberOfDesigns: std.StringHashMap(u64),

    fn printShit(self: *Context) void {
        print("Patterns:", .{});
        for (self.patterns) |d| {
            print("{s}", .{d.pattern});
        }

        print("", .{});

        print("Designs:", .{});
        for (self.designs) |p| {
            print("{s}", .{p.pattern});
        }
    }

    fn getPattern(self: *Context, s: []const u8) ?Pattern {
        for (self.patterns) |p| {
            if (sameArrays(p.pattern, s)) {
                return p;
            }
        }
        return null;
    }

    fn checkDesigns(self: *Context) !void {
        var counter: u64 = 0;
        var counter2: u64 = 0;
        for (self.designs) |design| {
            const num = try self.checkDesign(design);
            counter2 += num;
            if (num > 0) {
                counter += 1;
            }
        }

        print("Number of designs that are possible: {d}", .{counter});
        print("Number of designs combinations: {d}", .{counter2});
    }

    fn checkDesign(self: *Context, design: Design) !u64 {
        if (design.pattern.len == 0) {
            return 1;
        }
        if (self.numberOfDesigns.get(design.pattern)) |c| {
            return c;
        }
        var total: u64 = 0;
        for (self.patterns) |p| {
            if (design.startsWith(p)) {
                const nd = design.removePrefix(p);
                const nt = try self.checkDesign(nd);
                total += nt;
                try self.numberOfDesigns.put(nd.pattern, nt);
            }
        }

        return total;
    }
};

fn sameArrays(a: []const u8, target: []const u8) bool {
    if (target.len != a.len) {
        return false;
    }
    for (0..target.len) |i| {
        if (target[i] != a[i]) return false;
    }
    return true;
}
