const std = @import("std");
pub const print = @import("utils.zig").print;

const DataSource = enum { sample, sample2, real };
const source: DataSource = .real;

const verbose: bool = switch (source) {
    .sample => true,
    .sample2 => true,
    .real => false,
};

const filename: []const u8 = switch (source) {
    .sample => "puzzle21.data.sample",
    .sample2 => "puzzle21.data.sample2",
    .real => "puzzle21.data",
};

pub fn puzzle() !void {
    const allocator = std.heap.page_allocator;
    var lines = std.ArrayList([]const u8).init(allocator);
    defer lines.deinit();

    const file = @embedFile(filename);
    const split = std.mem.split;
    var splits = split(u8, file, "\n");
    while (splits.next()) |line| {
        if (line.len == 0) {
            continue;
        }
        try lines.append(line);
    }

    var ctx: Context = Context{
        .lines = lines.items,
        .queue = std.ArrayList(State).init(allocator),
        .prev = allocator.alloc(usize, 300) catch unreachable,
        .pch = allocator.alloc(u8, 300) catch unreachable,
        .buf = allocator.alloc(u8, 256) catch unreachable,
        .cache = std.AutoHashMap(u64, usize).init(allocator),
    };

    const c1 = ctx.complexities(3);
    print("Sum of complexities with 3 robots: {d}", .{c1});

    const c2 = ctx.complexities(26);
    print("Sum of complexities with 26 robots: {d}", .{c2});
}

const Keypad1 = enum { one, two, three, four, five, six, seven, eight, nine, zero, enter };

const Keypad2 = enum { up, down, left, right, push };

pub const State = struct {
    pos1: Keypad1,
    pos2: Keypad2,
    pos3: Keypad2,

    fn code(self: State) usize {
        const pos1: usize = @intFromEnum(self.pos1);
        const pos2: usize = @intFromEnum(self.pos2);
        const pos3: usize = @intFromEnum(self.pos3);
        return ((pos1 * 5 + pos2) * 5 + pos3) + 1;
    }

    fn of(x: usize) State {
        var t = x - 1;
        const pos3: Keypad2 = @enumFromInt(t % 5);
        t = t / 5;
        const pos2: Keypad2 = @enumFromInt(t % 5);
        t = t / 5;
        const pos1: Keypad1 = @enumFromInt(t);
        return State{ .pos1 = pos1, .pos2 = pos2, .pos3 = pos3 };
    }

    fn from(ch: u8) State {
        const pos: Keypad1 = switch (ch) {
            '0' => Keypad1.zero,
            '1' => Keypad1.one,
            '2' => Keypad1.two,
            '3' => Keypad1.three,
            '4' => Keypad1.four,
            '5' => Keypad1.five,
            '6' => Keypad1.six,
            '7' => Keypad1.seven,
            '8' => Keypad1.eight,
            '9' => Keypad1.nine,
            else => Keypad1.enter,
        };
        return State{ .pos1 = pos, .pos2 = Keypad2.push, .pos3 = Keypad2.push };
    }

    fn equal(self: State, other: State) bool {
        return self.pos1 == other.pos1 and self.pos2 == other.pos2 and self.pos3 == other.pos3;
    }
};

const Context = struct {
    lines: [][]const u8,
    queue: std.ArrayList(State),
    cache: std.AutoHashMap(u64, usize),
    prev: []usize,
    pch: []u8,
    buf: []u8,

    fn length(self: *Context, code: []const u8, depth: usize) usize {
        const ck = cache_key(code, depth);
        if (depth == 0) return code.len;
        if (self.cache.contains(ck)) return self.cache.get(ck) orelse unreachable;
        var prev: u8 = 'A';
        var tot_len: usize = 0;
        for (code) |ch| {
            const candidates = expand1(prev, ch);
            var min_len: usize = 0;
            for (candidates) |candidate| {
                const sub = length(self, candidate, depth - 1);
                if (min_len == 0 or sub < min_len) min_len = sub;
            }
            prev = ch;
            tot_len += min_len;
        }
        self.cache.put(ck, tot_len) catch unreachable;
        return tot_len;
    }

    fn complexities(self: *Context, depth: usize) usize {
        var prev: u8 = 'A';
        var ctot: usize = 0;
        for (self.lines) |line| {
            var tot_len: usize = 0;
            var entry: usize = 0;
            for (line) |ch| {
                if (ch != 'A') entry = entry * 10 + @as(usize, @intCast(ch - '0'));
                const candidates = expand2(prev, ch);
                var min_len: usize = std.math.maxInt(usize);
                for (candidates) |candidate| {
                    const sub = length(self, candidate, depth - 1);
                    if (sub < min_len) min_len = sub;
                }
                prev = ch;
                tot_len += min_len;
            }
            // if (verbose) {
            //     print("Code {d} - length {d}", .{ entry, tot_len });
            // }
            ctot += entry * tot_len;
        }
        return ctot;
    }

    fn maybe_add(self: *Context, cur: State, next: State, distance: []usize, ch: u8) void {
        if (distance[next.code()] == 0) {
            distance[next.code()] = distance[cur.code()] + 1;
            self.prev[next.code()] = cur.code();
            self.pch[next.code()] = ch;
            self.queue.append(next) catch unreachable;
        }
    }

    fn maybe_move3(self: *Context, cur: State, pos3: Keypad2, distance: []usize, ch: u8) void {
        var next = cur;
        next.pos3 = pos3;
        self.maybe_add(cur, next, distance, ch);
    }

    fn maybe_move2(self: *Context, cur: State, pos2: Keypad2, distance: []usize, ch: u8) void {
        var next = cur;
        next.pos2 = pos2;
        self.maybe_add(cur, next, distance, ch);
    }

    fn maybe_move1(self: *Context, cur: State, pos1: Keypad1, distance: []usize, ch: u8) void {
        var next = cur;
        next.pos1 = pos1;
        self.maybe_add(next, distance, ch);
    }

    fn bfs(self: *Context, start: State, end: State) usize {
        var distance = [_]usize{0} ** 300;
        distance[start.code()] = 1;
        self.queue.clearRetainingCapacity();
        self.queue.append(start) catch unreachable;
        var idx: usize = 0;
        while (idx < self.queue.items.len) : (idx += 1) {
            const cur = self.queue.items[idx];
            if (cur.equal(end)) return distance[end.code()] - 1;
            switch (cur.pos3) {
                Keypad2.up => {
                    self.maybe_move3(cur, .Down, &distance, 'v');
                    self.maybe_move3(cur, .Push, &distance, '>');
                    if (cur.pos2 == Keypad2.down)
                        self.maybe_move2(cur, .Up, &distance, 'A');
                    if (cur.pos2 == Keypad2.right)
                        self.maybe_move2(cur, .Push, &distance, 'A');
                },
                Keypad2.down => {
                    self.maybe_move3(cur, .Up, &distance, '^');
                    self.maybe_move3(cur, .Left, &distance, '<');
                    self.maybe_move3(cur, .Right, &distance, '>');
                    if (cur.pos2 == Keypad2.up)
                        self.maybe_move2(cur, .Down, &distance, 'A');
                    if (cur.pos2 == Keypad2.push)
                        self.maybe_move2(cur, .Right, &distance, 'A');
                },
                Keypad2.left => {
                    self.maybe_move3(cur, .Down, &distance, '>');
                    if (cur.pos2 == Keypad2.push)
                        self.maybe_move2(cur, .Up, &distance, 'A');
                    if (cur.pos2 == Keypad2.right)
                        self.maybe_move2(cur, .Down, &distance, 'A');
                    if (cur.pos2 == Keypad2.down)
                        self.maybe_move2(cur, .Left, &distance, 'A');
                },
                Keypad2.right => {
                    self.maybe_move3(cur, .Down, &distance, '<');
                    self.maybe_move3(cur, .Push, &distance, '^');
                    if (cur.pos2 == Keypad2.up)
                        self.maybe_move2(cur, .Push, &distance, 'A');
                    if (cur.pos2 == Keypad2.down)
                        self.maybe_move2(cur, .Right, &distance, 'A');
                    if (cur.pos2 == Keypad2.left)
                        self.maybe_move2(cur, .Down, &distance, 'A');
                },
                Keypad2.push => {
                    self.maybe_move3(cur, .Up, &distance, '<');
                    self.maybe_move3(cur, .Right, &distance, 'v');
                    switch (cur.pos2) {
                        Keypad2.up => {
                            switch (cur.pos1) {
                                Keypad1.zero => self.maybe_move1(cur, Keypad1.two, &distance, 'A'),
                                Keypad1.enter => self.maybe_move1(cur, Keypad1.three, &distance, 'A'),
                                Keypad1.one => self.maybe_move1(cur, Keypad1.four, &distance, 'A'),
                                Keypad1.two => self.maybe_move1(cur, Keypad1.five, &distance, 'A'),
                                Keypad1.three => self.maybe_move1(cur, Keypad1.six, &distance, 'A'),
                                Keypad1.four => self.maybe_move1(cur, Keypad1.seven, &distance, 'A'),
                                Keypad1.five => self.maybe_move1(cur, Keypad1.eight, &distance, 'A'),
                                Keypad1.six => self.maybe_move1(cur, Keypad1.nine, &distance, 'A'),
                                else => continue,
                            }
                        },
                        Keypad2.down => {
                            switch (cur.pos1) {
                                Keypad1.two => self.maybe_move1(cur, Keypad1.zero, &distance, 'A'),
                                Keypad1.three => self.maybe_move1(cur, Keypad1.enter, &distance, 'A'),
                                Keypad1.four => self.maybe_move1(cur, Keypad1.one, &distance, 'A'),
                                Keypad1.five => self.maybe_move1(cur, Keypad1.two, &distance, 'A'),
                                Keypad1.six => self.maybe_move1(cur, Keypad1.three, &distance, 'A'),
                                Keypad1.seven => self.maybe_move1(cur, Keypad1.four, &distance, 'A'),
                                Keypad1.eight => self.maybe_move1(cur, Keypad1.five, &distance, 'A'),
                                Keypad1.nine => self.maybe_move1(cur, Keypad1.six, &distance, 'A'),
                                else => continue,
                            }
                        },
                        Keypad2.left => {
                            switch (cur.pos1) {
                                Keypad1.enter => self.maybe_move1(cur, Keypad1.zero, &distance, 'A'),
                                Keypad1.two => self.maybe_move1(cur, Keypad1.one, &distance, 'A'),
                                Keypad1.three => self.maybe_move1(cur, Keypad1.two, &distance, 'A'),
                                Keypad1.five => self.maybe_move1(cur, Keypad1.four, &distance, 'A'),
                                Keypad1.six => self.maybe_move1(cur, Keypad1.five, &distance, 'A'),
                                Keypad1.eight => self.maybe_move1(cur, Keypad1.seven, &distance, 'A'),
                                Keypad1.nine => self.maybe_move1(cur, Keypad1.eight, &distance, 'A'),
                                else => continue,
                            }
                        },
                        Keypad2.right => {
                            switch (cur.pos1) {
                                Keypad1.zero => self.maybe_move1(cur, Keypad1.enter, &distance, 'A'),
                                Keypad1.one => self.maybe_move1(cur, Keypad1.two, &distance, 'A'),
                                Keypad1.two => self.maybe_move1(cur, Keypad1.three, &distance, 'A'),
                                Keypad1.four => self.maybe_move1(cur, Keypad1.five, &distance, 'A'),
                                Keypad1.five => self.maybe_move1(cur, Keypad1.six, &distance, 'A'),
                                Keypad1.seven => self.maybe_move1(cur, Keypad1.eight, &distance, 'A'),
                                Keypad1.eight => self.maybe_move1(cur, Keypad1.nine, &distance, 'A'),
                                else => continue,
                            }
                        },
                        else => {},
                    }
                },
            }
        }
        return 0;
    }
};

fn expand1(from: u8, to: u8) []const []const u8 {
    return switch (from) {
        '<' => switch (to) {
            '^' => &.{">^A"},
            'v' => &.{">A"},
            '>' => &.{">>A"},
            'A' => &.{">>^A"},
            else => &.{"A"},
        },
        'v' => switch (to) {
            '^' => &.{"^A"},
            '<' => &.{"<A"},
            '>' => &.{">A"},
            'A' => &.{ ">^A", "^>A" },
            else => &.{"A"},
        },
        '>' => switch (to) {
            'v' => &.{"<A"},
            '<' => &.{"<<A"},
            'A' => &.{"^A"},
            '^' => &.{ "^<A", "<^A" },
            else => &.{"A"},
        },
        '^' => switch (to) {
            'v' => &.{"vA"},
            '<' => &.{"v<A"},
            'A' => &.{">A"},
            '>' => &.{ ">vA", "v>A" },
            else => &.{"A"},
        },
        'A' => switch (to) {
            '^' => &.{"<A"},
            '>' => &.{"vA"},
            'v' => &.{ "<vA", "v<A" },
            '<' => &.{"v<<A"},
            else => &.{"A"},
        },
        else => &.{},
    };
}

fn expand2(from: u8, to: u8) []const []const u8 {
    return switch (from) {
        '0' => switch (to) {
            '0' => &.{"A"},
            '1' => &.{"^<A"},
            '2' => &.{"^A"},
            '3' => &.{ "^>A", ">^A" },
            '4' => &.{"^^<A"},
            '5' => &.{"^^A"},
            '6' => &.{ "^^>A", ">^^A" },
            '7' => &.{"^^^<A"},
            '8' => &.{"^^^A"},
            '9' => &.{ "^^^>A", ">^^^A" },
            'A' => &.{">A"},
            else => &.{""},
        },
        '1' => switch (to) {
            '0' => &.{">vA"},
            '7' => &.{"^^A"},
            '8' => &.{ "^^>A", ">^^A" },
            '9' => &.{ "^^>>A", ">>^^A" },
            '4' => &.{"^A"},
            '5' => &.{ "^>A", ">^A" },
            '6' => &.{ "^>>A", ">>^A" },
            '1' => &.{"A"},
            '2' => &.{">A"},
            '3' => &.{">>A"},
            'A' => &.{">>vA"},
            else => &.{""},
        },
        '2' => switch (to) {
            '0' => &.{"vA"},
            '7' => &.{ "^^<A", "<^^A" },
            '8' => &.{"^^A"},
            '9' => &.{ "^^>A", ">^^A" },
            '4' => &.{ "^<A", "<^A" },
            '5' => &.{"^A"},
            '6' => &.{ "^>A", ">^A" },
            '1' => &.{"<A"},
            '2' => &.{"A"},
            '3' => &.{">A"},
            'A' => &.{ ">vA", "v>A" },
            else => &.{""},
        },
        '3' => switch (to) {
            '0' => &.{ "<vA", "v<A" },
            '7' => &.{ "^^<<A", "<<^^A" },
            '8' => &.{ "^^<A", "<^^A" },
            '9' => &.{"^^A"},
            '4' => &.{ "^<<A", "<<^A" },
            '5' => &.{ "^<A", "<^A" },
            '6' => &.{"^A"},
            '1' => &.{"<<A"},
            '2' => &.{"<A"},
            '3' => &.{"A"},
            'A' => &.{"vA"},
            else => &.{""},
        },
        '4' => switch (to) {
            '0' => &.{">vvA"},
            '7' => &.{"^A"},
            '8' => &.{ "^>A", ">^A" },
            '9' => &.{ ">>^A", "^>>A" },
            '4' => &.{"A"},
            '5' => &.{">A"},
            '6' => &.{">>A"},
            '1' => &.{"vA"},
            '2' => &.{ "v>A", ">vA" },
            '3' => &.{ ">>vA", "v>>A" },
            'A' => &.{">>vvA"},
            else => &.{""},
        },
        '5' => switch (to) {
            '0' => &.{"vvA"},
            '7' => &.{ "^<A", "<^A" },
            '8' => &.{"^A"},
            '9' => &.{ "^>A", ">^A" },
            '4' => &.{"<A"},
            '5' => &.{"A"},
            '6' => &.{">A"},
            '1' => &.{ "v<A", "<vA" },
            '2' => &.{"vA"},
            '3' => &.{ "v>A", ">vA" },
            'A' => &.{ ">vvA", "vv>A" },
            else => &.{""},
        },
        '6' => switch (to) {
            '0' => &.{ "<vvA", "vv<A" },
            '7' => &.{ "<<^A", "^<<A" },
            '8' => &.{ "^<A", "<^A" },
            '9' => &.{"^A"},
            '4' => &.{"<<A"},
            '5' => &.{"<A"},
            '6' => &.{"A"},
            '1' => &.{ "<<vA", "v<<A" },
            '2' => &.{ "v<A", "<vA" },
            '3' => &.{"vA"},
            'A' => &.{"vvA"},
            else => &.{""},
        },
        '7' => switch (to) {
            '0' => &.{">vvvA"},
            '7' => &.{"A"},
            '8' => &.{">A"},
            '9' => &.{">>A"},
            '4' => &.{"vA"},
            '5' => &.{ ">vA", "v>A" },
            '6' => &.{ ">>vA", "v>>A" },
            '1' => &.{"vvA"},
            '2' => &.{ ">vvA", "vv>A" },
            '3' => &.{ ">>vvA", "vv>>A" },
            'A' => &.{">>vvvA"},
            else => &.{""},
        },
        '8' => switch (to) {
            '0' => &.{"vvvA"},
            '7' => &.{"<A"},
            '8' => &.{"A"},
            '9' => &.{">A"},
            '4' => &.{ "v<A", "<vA" },
            '5' => &.{"^A"},
            '6' => &.{ "v>A", ">vA" },
            '1' => &.{ "vv<A", "<vvA" },
            '2' => &.{"vvA"},
            '3' => &.{ "vv>A", ">vvA" },
            'A' => &.{ ">vvvA", "vvv>A" },
            else => &.{""},
        },
        '9' => switch (to) {
            '0' => &.{ "<vvvA", "vvv<A" },
            '7' => &.{"<<A"},
            '8' => &.{"<A"},
            '9' => &.{"A"},
            '4' => &.{ "<<vA", "v<<A" },
            '5' => &.{ "<vA", "v<A" },
            '6' => &.{"vA"},
            '1' => &.{ "<<vvA", "vv<<A" },
            '2' => &.{ "<vvA", "vv<A" },
            '3' => &.{"vvA"},
            'A' => &.{"vvvA"},
            else => &.{""},
        },
        'A' => switch (to) {
            '0' => &.{"<A"},
            '1' => &.{"^<<A"},
            '2' => &.{ "^<A", "<^A" },
            '3' => &.{"^A"},
            '4' => &.{"^^<<A"},
            '5' => &.{ "^^<A", "<^^A" },
            '6' => &.{"^^A"},
            '7' => &.{"^^^<<A"},
            '8' => &.{ "^^^<A", "<^^^A" },
            '9' => &.{"^^^A"},
            'A' => &.{"A"},
            else => &.{""},
        },
        else => &.{""},
    };
}

fn cache_key(code: []const u8, depth: usize) u64 {
    var ck: u64 = 0;
    for (code) |ch| ck = (ck << 8) | @as(u64, ch);
    return (ck << 8) + @as(u64, @intCast(depth));
}
