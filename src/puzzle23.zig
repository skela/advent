const std = @import("std");
const utils = @import("utils.zig");
const print = utils.print;
const alloc = std.heap.page_allocator;

const DataSource = enum { sample, real };
const source: DataSource = .real;

const verbose: bool = switch (source) {
    .sample => true,
    .real => false,
};

const filename: []const u8 = switch (source) {
    .sample => "puzzle23.data.sample",
    .real => "puzzle23.data",
};

pub fn puzzle() !void {
    var connections = std.ArrayList(Connection).init(alloc);
    defer connections.deinit();

    var computers = std.PriorityQueue(Computer, void, sortComputers).init(alloc, undefined);
    defer computers.deinit();

    const file = @embedFile(filename);
    const split = std.mem.split;
    var splits = split(u8, file, "\n");
    while (splits.next()) |line| {
        if (line.len == 0) {
            continue;
        }
        const left = Computer{ .name = line[0..2] };
        const right = Computer{ .name = line[3..] };
        try connections.append(Connection{ .a = left, .b = right });
        try connections.append(Connection{ .a = right, .b = left });

        if (!containsComputer(computers.items, left)) try computers.add(left);
        if (!containsComputer(computers.items, right)) try computers.add(right);
    }

    if (verbose) {
        print("Connections: ", .{});
        for (connections.items) |c| {
            print("  {s}-{s}", .{ c.a.name, c.b.name });
        }
    }

    if (verbose) {
        print("Computers: ", .{});
        for (computers.items) |c| {
            print("  {s}", .{c.name});
        }
    }

    var clusterMap = std.StringHashMap(Cluster).init(alloc);
    defer clusterMap.deinit();

    for (connections.items) |c| {
        if (clusterMap.get(c.a.name)) |oc| {
            var cluster = Cluster{ .computers = std.PriorityQueue(Computer, void, sortComputers).init(alloc, undefined) };
            for (oc.computers.items) |occ| {
                try cluster.computers.add(occ);
            }
            if (!clusterContainsComputer(cluster, c.b)) {
                try cluster.computers.add(c.b);
                try clusterMap.put(c.a.name, cluster);
            }
        } else {
            var cluster = Cluster{ .computers = std.PriorityQueue(Computer, void, sortComputers).init(alloc, undefined) };
            try cluster.computers.add(c.b);
            try clusterMap.put(c.a.name, cluster);
        }

        if (clusterMap.get(c.b.name)) |oc| {
            var cluster = Cluster{ .computers = std.PriorityQueue(Computer, void, sortComputers).init(alloc, undefined) };
            for (oc.computers.items) |occ| {
                try cluster.computers.add(occ);
            }
            if (!clusterContainsComputer(cluster, c.a)) {
                try cluster.computers.add(c.a);
                try clusterMap.put(c.b.name, cluster);
            }
        } else {
            var cluster = Cluster{ .computers = std.PriorityQueue(Computer, void, sortComputers).init(alloc, undefined) };
            try cluster.computers.add(c.a);
            try clusterMap.put(c.b.name, cluster);
        }
    }

    var clusters = std.StringHashMap(Cluster).init(alloc);
    defer clusters.deinit();

    for (computers.items) |computer| {
        if (clusterMap.get(computer.name)) |neighbors| {
            for (neighbors.computers.items) |neighbor| {
                if (clusterMap.get(neighbor.name)) |others| {
                    for (others.computers.items) |other| {
                        if (containsComputer(neighbors.computers.items, other)) {
                            var group = std.PriorityQueue(Computer, void, sortComputers).init(alloc, undefined);
                            try group.add(computer);
                            try group.add(neighbor);
                            try group.add(other);
                            sortComputerSlice(group.items);
                            const formatted_string = try std.fmt.allocPrint(alloc, "{}-{}-{}", .{ group.items[0], group.items[1], group.items[2] });
                            try clusters.put(formatted_string, Cluster{ .computers = group });
                        }
                    }
                }
            }
        }
    }

    var keys = clusters.valueIterator();
    var numberOfClusters: usize = 0;
    while (keys.next()) |v| {
        const comps = v.*.computers;
        if (clusterContainsComputerStartingWithT(v.*)) {
            if (verbose) {
                print("Cluster: ", .{});
                for (comps.items) |c| {
                    print("  {s}", .{c.name});
                }
            }
            numberOfClusters += 1;
        }
    }

    print("Number of clusters: {d}", .{numberOfClusters});

    var largestGroup = std.PriorityQueue(Computer, void, sortComputers).init(alloc, undefined);
    for (computers.items) |computer| {
        var group = std.PriorityQueue(Computer, void, sortComputers).init(alloc, undefined);
        try group.add(computer);
        if (clusterMap.get(computer.name)) |neighbors| {
            for (neighbors.computers.items) |neighbor| {
                var hasAll: bool = true;
                for (group.items) |n| {
                    if (clusterMap.get(neighbor.name)) |cl| {
                        if (!containsComputer(cl.computers.items, n)) hasAll = false;
                    }
                }
                if (hasAll) try group.add(neighbor);
            }

            sortComputerSlice(group.items);
            if (group.count() > largestGroup.count()) {
                largestGroup = group;
            }
        }
    }

    std.debug.print("Largest cluster: {s}", .{largestGroup.items[0].name});
    for (1..largestGroup.items.len) |i| {
        const c = largestGroup.items[i];
        std.debug.print(",{s}", .{c.name});
    }
    std.debug.print("\n", .{});
}

fn clusterContainsComputerStartingWithT(cluster: Cluster) bool {
    for (cluster.computers.items) |c| {
        if (c.name[0] == 't') return true;
    }
    return false;
}

fn clusterContainsComputer(cluster: Cluster, computer: Computer) bool {
    return containsComputer(cluster.computers.items, computer);
}

fn containsComputer(computers: []Computer, computer: Computer) bool {
    for (computers) |c| {
        if (isStringEqual(c.name, computer.name)) return true;
    }
    return false;
}

fn isStringEqual(a: []const u8, b: []const u8) bool {
    for (0..a.len) |i| {
        if (a[i] != b[i]) return false;
    }
    return true;
}

const Computer = struct {
    name: []const u8,
};

const Connection = struct {
    a: Computer,
    b: Computer,
};

const Cluster = struct {
    computers: std.PriorityQueue(Computer, void, sortComputers),
};

fn sortComputers(context: void, a: Computer, b: Computer) std.math.Order {
    _ = context;
    return std.mem.order(u8, a.name, b.name);
}

fn lessThan(_: void, lhs: []const u8, rhs: []const u8) bool {
    return std.mem.order(u8, lhs, rhs) == .lt;
}

fn sortStringSlice(slice: [][]const u8) void {
    std.mem.sort([]const u8, slice, {}, lessThan);
}

fn lessThanComputer(_: void, lhs: Computer, rhs: Computer) bool {
    return std.mem.order(u8, lhs.name, rhs.name) == .lt;
}

fn sortComputerSlice(slice: []Computer) void {
    std.mem.sort(Computer, slice, {}, lessThanComputer);
}
