const std = @import("std");
pub const print = @import("utils.zig").print;

const Task = enum { one, two };
const task: Task = Task.one;
const sample: bool = false;
const verbose: bool = false;

pub fn puzzle() !void {
    var lookup = std.AutoArrayHashMap(StoneKey, u64).init(std.heap.page_allocator);
    defer lookup.deinit();

    var stones = std.ArrayList(Stone).init(std.heap.page_allocator);
    defer stones.deinit();

    const file = @embedFile(if (sample) "puzzle11.data.sample" else "puzzle11.data");
    const split = std.mem.split;
    var splits = split(u8, file, "\n");

    while (splits.next()) |line| {
        if (line.len == 0) {
            continue;
        }

        var parts = split(u8, line, " ");

        while (parts.next()) |part| {
            const v = try std.fmt.parseInt(u64, part, 10);
            try stones.append(try stoneForValue(v));
        }
    }

    if (verbose) {
        printStones(stones.items);
        // printStoneChars(stones.items);
    }

    const number_of_blinks: usize = 75;
    // for (0..number_of_blinks) |b| {
    //     print("Blink {d}", .{b + 1});
    //     var offset: usize = 0;
    //     for (0..stones.items.len) |it| {
    //         const i = it + offset;
    //         const s = stones.items[i];
    //         if (s.value == 0) {
    //             try stones.items[i].update(1);
    //         } else if (isEven(s.chars.len)) {
    //             const res = try s.split();
    //             const s1 = res.s1;
    //             const s2 = res.s2;
    //             stones.items[i] = s1;
    //             try stones.insert(i + 1, s2);
    //             offset += 1;
    //         } else {
    //             try stones.items[i].update(stones.items[i].value * 2024);
    //         }
    //     }
    //     if (verbose) {
    //         printStones(stones.items);
    //     }
    // }

    var number_of_stones: u64 = 0;
    for (stones.items) |s| {
        number_of_stones += try blink(&lookup, s, number_of_blinks);
    }

    print("Number of stones after {d} blinks: {d}", .{ number_of_blinks, number_of_stones });

    // printStones(stones.items);
    // printStoneChars(stones.items);
}

const Stone = struct {
    value: u64,
    number_of_digts: usize,

    // fn update(self: *Stone, value: u64) !void {
    //     self.value = value;
    //
    //     const max_len = 40;
    //     var buf: [max_len]u8 = undefined;
    //     const numAsString = try std.fmt.bufPrint(&buf, "{}", .{value});
    //
    //     var chars = std.ArrayList(u8).init(std.heap.page_allocator);
    //     for (numAsString) |u| {
    //         try chars.append(u);
    //     }
    //     self.chars = chars.items;
    //
    //     // const allocator = std.heap.page_allocator;
    //     // var list = std.ArrayList(u8).initCapacity(allocator, 20);
    //     // try std.fmt.format(&list, "{}", .{value});
    //     // defer allocator.free(list);
    //     // self.chars = try list.toOwnedSlice();
    //     // var buffer: [12]u8 = undefined; // 11 chars for max u64 + 1 for null terminator
    //     // const written = std.fmt.bufPrint(&buffer, "{}", .{value});
    //     //
    //     // const result: []const u8 = buffer[0..written];
    //     // self.chars = result;
    // }
    pub fn split(self: Stone) !SplitStone {
        const max_len = 40;
        var buf: [max_len]u8 = undefined;
        const numAsString = try std.fmt.bufPrint(&buf, "{}", .{self.value});

        var chars = std.ArrayList(u8).init(std.heap.page_allocator);
        defer chars.deinit();
        for (numAsString) |u| {
            try chars.append(u);
        }

        const len = chars.items.len / 2;
        const c1 = chars.items[0..len];
        const c2 = chars.items[len..];

        const v1 = try std.fmt.parseInt(u64, c1, 10);
        const s1 = try stoneForValue(v1);

        const v2 = try std.fmt.parseInt(u64, c2, 10);
        const s2 = try stoneForValue(v2);
        return SplitStone{ .s1 = s1, .s2 = s2 };
    }
};

fn stoneForValue(value: u64) !Stone {
    const max_len = 40;
    var buf: [max_len]u8 = undefined;
    const numAsString = try std.fmt.bufPrint(&buf, "{}", .{value});

    var chars = std.ArrayList(u8).init(std.heap.page_allocator);
    defer chars.deinit();
    for (numAsString) |u| {
        try chars.append(u);
    }
    const s: Stone = Stone{ .value = value, .number_of_digts = chars.items.len };
    return s;
}

const SplitStone = struct {
    s1: Stone,
    s2: Stone,
};

const StoneKey = struct {
    value: u64,
    depth: u64,
};

fn printStones(list: []Stone) void {
    for (list) |s| {
        std.debug.print("{d} ", .{s.value});
    }
    std.debug.print("\n", .{});
}

// fn printStoneChars(list: []Stone) void {
//     for (list) |s| {
//         std.debug.print("{c} ", .{s.chars});
//     }
//     std.debug.print("\n", .{});
// }

fn isEven(n: usize) bool {
    return n % 2 == 0;
}

fn blink(lookup: *std.AutoArrayHashMap(StoneKey, u64), s: Stone, b: u64) !u64 {
    if (b == 0) {
        return 1;
    }

    const ps = lookup.get(StoneKey{ .value = s.value, .depth = b });
    if (ps) |v| {
        return v;
    }

    var result: u64 = 0;
    if (s.value == 0) {
        result = try blink(lookup, try stoneForValue(1), b - 1);
    } else if (isEven(s.number_of_digts)) {
        const res = try s.split();
        const s1 = res.s1;
        const s2 = res.s2;
        result = try blink(lookup, s1, b - 1) + try blink(lookup, s2, b - 1);
    } else {
        result = try blink(lookup, try stoneForValue(s.value * 2024), b - 1);
    }
    try lookup.put(StoneKey{ .value = s.value, .depth = b }, result);
    return result;
}
