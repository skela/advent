const std = @import("std");
const utils = @import("utils.zig");
const print = utils.print;
const alloc = std.heap.page_allocator;

const DataSource = enum { sample, sample2, real };
const source: DataSource = .real;

const iterations: usize = switch (source) {
    .sample => 2000,
    .sample2 => 2000,
    .real => 2000,
};

const verbose: bool = switch (source) {
    .sample => true,
    .sample2 => true,
    .real => false,
};

const filename: []const u8 = switch (source) {
    .sample => "puzzle22.data.sample",
    .sample2 => "puzzle22.data.sample2",
    .real => "puzzle22.data",
};

pub fn puzzle() !void {
    var buyers = std.ArrayList(i64).init(std.heap.page_allocator);
    defer buyers.deinit();

    const file = @embedFile(filename);
    const split = std.mem.split;
    var splits = split(u8, file, "\n");
    while (splits.next()) |line| {
        if (line.len == 0) {
            continue;
        }
        const buyer: i64 = try parseNumber(line);
        try buyers.append(buyer);
    }

    // print("{d}", .{mix(42, 15)});
    // print("{d}", .{prune(100000000)});
    // print("{d}", .{calc(123, 10)});

    var sum: i64 = 0;
    for (buyers.items) |b| {
        const res = calc(b, iterations - 1);
        if (verbose) {
            print("Buyer {d} secret number is {d}", .{ b, res });
        }
        sum += res;
    }

    print("The total sum is {d}", .{sum});
    // print("{d}", .{calc(123, 9)});

    var possibleSequences = std.AutoArrayHashMap(Sequence, i64).init(alloc);

    defer possibleSequences.deinit();

    for (buyers.items) |secretNumber| {
        var alreadyAdded = std.AutoArrayHashMap(Sequence, bool).init(alloc);
        var runningSequence = std.ArrayList(i64).init(alloc);

        defer alreadyAdded.deinit();
        defer runningSequence.deinit();

        var previousSecretNumber = secretNumber;
        var currentNumber = secretNumber;

        for (0..iterations) |_| {
            try runningSequence.append(bananas(currentNumber) - bananas(previousSecretNumber));
            previousSecretNumber = currentNumber;
            currentNumber = calc(currentNumber, 0);
            if (runningSequence.items.len == 4) {
                const seq = Sequence{
                    .one = runningSequence.items[0],
                    .two = runningSequence.items[1],
                    .three = runningSequence.items[2],
                    .four = runningSequence.items[3],
                };

                if (alreadyAdded.get(seq) == null) {
                    if (possibleSequences.get(seq)) |op| {
                        try possibleSequences.put(seq, op + bananas(previousSecretNumber));
                    } else {
                        try possibleSequences.put(seq, bananas(previousSecretNumber));
                    }
                    try alreadyAdded.put(seq, true);
                }
                _ = runningSequence.orderedRemove(0);
            }
        }
    }

    var maximum: i64 = 0;
    for (possibleSequences.values()) |v| {
        if (v > maximum) maximum = v;
    }

    print("Max bananas u can get is {d}", .{maximum});
}

fn calc(secret: i64, depth: usize) i64 {
    const step1 = prune(mix(secret, secret * 64));
    // if (verbose) {
    //     print("{d}", .{step1});
    // }
    const step2 = prune(mix(step1, @divFloor(step1, 32)));
    // if (verbose) {
    //     print("{d}", .{step2});
    // }
    const step3 = prune(mix(step2, step2 * 2048));
    // if (verbose) {
    //     print("{d}", .{step3});
    // }
    if (depth == 0) return step3;
    return calc(step3, depth - 1);
}

fn mix(secret: i64, value: i64) i64 {
    return secret ^ value;
}

fn prune(secret: i64) i64 {
    return @mod(secret, 16777216);
}

fn bananas(num: i64) i64 {
    return @intCast(@abs(num) % 10);
}

fn parseNumber(input: []const u8) !i64 {
    return try std.fmt.parseInt(i64, input, 10);
}

const Sequence = struct {
    one: i64,
    two: i64,
    three: i64,
    four: i64,
};
