const main1 = @import("main.zig");
const expression = main1.Expression;
const rule = main1.Rule;

const std = @import("std");

pub fn main() !void {
    var new_expression = expression{ .function = .{ .name = "add", .args = &.{ expression{ .symbol = .{ .str = "a" } }, expression{ .symbol = .{ .str = "b" } } } } };
    std.debug.print("{}\n", .{@TypeOf(expression)});
    std.debug.print("{}\n", .{@TypeOf(rule)});
    std.debug.print("{}\n", .{new_expression});
}
