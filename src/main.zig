const std = @import("std");
var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const allocator = gpa.allocator();
const stringmap = std.StringHashMap(Expression);
const map = std.AutoHashMap(Expression, Expression);
const arraylist = std.ArrayList(Expression);

//Declare a tagged union called an expression
//An expression can be a symbol, a function.
//A function has a name and a list of arguments
pub const Expression = union(enum) {
    symbol: struct { str: []const u8 },
    function: struct { name: []const u8, args: []const Expression },

    //Print an expression using the print function
    pub fn print(self: Expression) void {
        switch (self) {
            .symbol => |s| {
                std.debug.print("{s}", .{s.str});
            },
            .function => |f| {
                std.debug.print("{s}(", .{f.name});
                for (f.args, 0..) |arg, i| {
                    if (i > 0) {
                        std.debug.print(", ", .{});
                    }
                    arg.print();
                }
                std.debug.print(")", .{});
            },
        }
    }

    //Print an expression with the standard library using std.debug.print
    //This simply says how the expression should be printed when called in
    //std.debug.print
    pub fn format(
        self: Expression,
        comptime _: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        switch (self) {
            .symbol => |s| {
                try writer.print("{s}", .{s.str});
            },
            .function => |f| {
                try writer.print("{s}(", .{f.name});
                for (f.args, 0..) |arg, i| {
                    if (i > 0) {
                        try writer.print(", ", .{});
                    }
                    try arg.format("", .{}, writer);
                }
                try writer.print(")", .{});
            },
        }
    }

    // return true if the Expression is a function
    pub fn isFunction(self: Expression) bool {
        return switch (self) {
            .function => true,
            else => false,
        };
    }

    // return true if the Expression is a symbol
    pub fn isSymbol(self: Expression) bool {
        return switch (self) {
            .symbol => true,
            else => false,
        };
    }

    // return true if the two expressions are equal
    pub fn eql(self: Expression, other: Expression) bool {
        return switch (self) {
            .symbol => |s| switch (other) {
                .symbol => |s2| std.mem.eql(u8, s.str, s2.str),
                else => false,
            },
            .function => |f| switch (other) {
                .function => |f2| std.meta.eql(f.name, f2.name) and eqlSlice(f.args, f2.args),
                else => false,
            },
        };
    }

    // return true if the two expression slices are equal
    pub fn eqlSlice(first: []const Expression, other: []const Expression) bool {
        if (first.len != other.len) return false;
        if (first.ptr == other.ptr) return true;
        for (first, other) |a, b| {
            switch (a) {
                .symbol => |s| switch (b) {
                    .symbol => |s2| if (std.mem.eql(u8, s.str, s2.str)) {},
                    .function => return false,
                },
                .function => |f| switch (b) {
                    .symbol => return false,
                    .function => |f2| if (std.mem.eql(u8, f.name, f2.name) and eqlSlice(f.args, f2.args)) {},
                },
            }
        }
        return true;
    }

    pub fn getlen(self: Expression) usize {
        return switch (self) {
            .symbol => |s| s.str.len,
            .function => |f| f.args.len,
        };
    }

    // return true if the two expressions are the same symbol, if they are functions then check if they have the same
    // parent function name and number of arguments
    // So add(g(c),f(d)) should still be a pattern of add(a,b)
    // In this case add is the same parent function and has the same number of arguments
    // So a would match to g(c) and b would match to f(d)
    pub fn isPattern(self: Expression, other: Expression) bool {
        return switch (self) {
            .symbol => |s| switch (other) {
                .symbol => |s2| std.mem.eql(u8, s.str, s2.str),
                .function => false,
            },
            .function => |f| switch (other) {
                .symbol => false,
                .function => |f2| std.mem.eql(u8, f.name, f2.name) and f.args.len == f2.args.len,
            },
        };
    }

    //put either a symbol or a function name in a hashmap
    pub fn putinMap(self: Expression, other: Expression, amap: *stringmap) !void {
        try switch (self) {
            .symbol => |s| switch (other) {
                .symbol => |_| if (!amap.contains(s.str)) {
                    try amap.put(s.str, other);
                } else {
                    var entry = amap.get(s.str).?;
                    if (!entry.eql(other)) {
                        if (amap.remove(s.str)) {
                            std.debug.print("NO MATCH\n", .{});
                        }
                    }
                },
                .function => |_| amap.put(s.str, other),
            },
            .function => |f| switch (other) {
                .symbol => |_| amap.put(f.name, other),
                .function => |_| {
                    //try amap.put(f.name, other);
                    for (f.args, other.function.args, 0..) |_, _, i| {
                        try f.args[i].putinMap(other.function.args[i], amap);
                    }
                },
            },
        };
    }

    //Correctly pattern match variables if they pass the 'isPattern' condition.
    pub fn patternMatch(self: Expression, other: Expression) !void {
        var mymap = stringmap.init(allocator);
        defer mymap.deinit();
        if (self.isPattern(other)) {
            try self.putinMap(other, &mymap);
            var iter = mymap.iterator();
            while (iter.next()) |entry| {
                std.debug.print("{s} => {s}\n", .{ entry.key_ptr.*, entry.value_ptr.* });
            }
        } else {
            std.debug.print("NO MATCH\n", .{});
        }
    }
};

pub const NoMatch = error{NO_MATCH};

//A rule is a struct that has an expression and its equivalent
//A rule enforces that the expression and equivalent are the same
//i.e a + b ≡ b + a
pub const Rule = struct {
    expression: Expression,
    equivalent: Expression,

    //Print a rule using the print function from Expression
    pub fn print(self: Rule) void {
        self.expression.print();
        std.debug.print(" ≡ ", .{});
        self.equivalent.print();
        std.debug.print("\n", .{});
    }

    //Print a rule with the standard library using std.debug.print
    pub fn format(
        self: Rule,
        comptime _: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        try self.expression.format("", .{}, writer);
        try writer.print(" ≡ ", .{});
        try self.equivalent.format("", .{}, writer);
        try writer.print("\n", .{});
    }

    //Apply a rule to an expression
    pub fn apply(self: Rule, expr: Expression) !Expression {
        if (self.expression.isPattern(expr)) {
            var amap = stringmap.init(allocator);
            defer amap.deinit();
            var temp = self.equivalent.putinMap(expr, &amap) catch return NoMatch.NO_MATCH; // this is a function that put inserts a (string, Expression) pair
            _ = temp;
            var iter = amap.iterator(); // make the map an iterator
            const arg_len = self.equivalent.function.args.len;
            return switch (self.expression) {
                .symbol => |_| switch (expr) {
                    .symbol => |_| self.equivalent,
                    .function => unreachable,
                },
                .function => |_| switch (expr) {
                    .symbol => unreachable,
                    .function => |_| {
                        var arg_arr = allocator.alloc(Expression, arg_len) catch return NoMatch.NO_MATCH;
                        var k = arg_len - 1;
                        while (iter.next()) |entry| {
                            if (self.expression.isPattern(entry.value_ptr.*)) {
                                arg_arr[k] = try self.apply(entry.value_ptr.*);
                            } else {
                                arg_arr[k] = entry.value_ptr.*;
                            }
                            //std.debug.print("{}\n", .{sub});

                            if (k > 0) {
                                k -= 1;
                            }
                        }
                        const arg_slice = arg_arr[0..arg_len];

                        var new_expr = Expression{ .function = .{ .name = self.equivalent.function.name, .args = arg_slice } };
                        return new_expr;
                    },
                },
            };
        }
        for (expr.function.args) |arg| {
            if (self.expression.isPattern(arg)) {
                return try self.apply(arg);
            }
        }
        return NoMatch.NO_MATCH;
    }
};

//Some mathematical rules declarations
pub const swap_expr = Rule{
    .expression = Expression{ .function = .{ .name = "swap", .args = &.{
        Expression{ .function = .{ .name = "pair", .args = &.{ Expression{ .symbol = .{ .str = "a" } }, Expression{ .symbol = .{ .str = "b" } } } } },
    } } },
    .equivalent = Expression{ .function = .{ .name = "pair", .args = &.{ Expression{ .symbol = .{ .str = "b" } }, Expression{ .symbol = .{ .str = "a" } } } } },
};

pub const addition_expr = Rule{
    .expression = Expression{ .function = .{ .name = "add", .args = &.{
        Expression{ .symbol = .{ .str = "a" } }, Expression{ .symbol = .{ .str = "b" } },
    } } },
    .equivalent = Expression{ .function = .{ .name = "add", .args = &.{
        Expression{ .symbol = .{ .str = "b" } }, Expression{ .symbol = .{ .str = "a" } },
    } } },
};

pub const multiply_expr = Rule{
    .expression = Expression{ .function = .{ .name = "mult", .args = &.{
        Expression{ .symbol = .{ .str = "a" } }, Expression{ .symbol = .{ .str = "b" } },
    } } },
    .equivalent = Expression{ .function = .{ .name = "mult", .args = &.{
        Expression{ .symbol = .{ .str = "b" } }, Expression{ .symbol = .{ .str = "a" } },
    } } },
};

pub const division_expr = Rule{
    .expression = Expression{ .function = .{ .name = "div", .args = &.{
        Expression{ .symbol = .{ .str = "a" } }, Expression{ .symbol = .{ .str = "b" } },
    } } },
    .equivalent = Expression{ .function = .{ .name = "mult", .args = &.{
        Expression{ .symbol = .{ .str = "a" } }, Expression{ .symbol = .{ .str = "1/b" } },
    } } },
};

pub const square_expr = Rule{
    .expression = Expression{ .function = .{ .name = "square", .args = &.{
        Expression{ .symbol = .{ .str = "a" } },
    } } },
    .equivalent = Expression{ .function = .{ .name = "mult", .args = &.{
        Expression{ .symbol = .{ .str = "a" } }, Expression{ .symbol = .{ .str = "a" } },
    } } },
};

pub const power_expr = Rule{
    .expression = Expression{ .function = .{ .name = "power", .args = &.{
        Expression{ .symbol = .{ .str = "a" } }, Expression{ .symbol = .{ .str = "n" } },
    } } },
    .equivalent = Expression{ .function = .{ .name = "mult", .args = &.{
        Expression{ .symbol = .{ .str = "a" } }, Expression{ .function = .{ .name = "power", .args = &.{
            Expression{ .symbol = .{ .str = "a" } },
            Expression{ .symbol = .{ .str = "n-1" } },
        } } },
    } } },
};

pub const expand_expr1 = Rule{
    .expression = Expression{ .function = .{ .name = "expand", .args = &.{
        Expression{ .function = .{ .name = "mult", .args = &.{ Expression{ .function = .{ .name = "add", .args = &.{ Expression{ .symbol = .{ .str = "a" } }, Expression{ .symbol = .{ .str = "b" } } } } }, Expression{ .symbol = .{ .str = "c" } } } } },
    } } },
    .equivalent = Expression{ .function = .{ .name = "add", .args = &.{
        Expression{ .symbol = .{ .str = "ac" } }, Expression{ .symbol = .{ .str = "bc" } },
    } } },
};

pub fn main() !void {

    //Print some of the rules defined
    swap_expr.print();
    addition_expr.print();
    multiply_expr.print();
    division_expr.print();
    square_expr.print();
    power_expr.print();
    expand_expr1.print();

    var add1 = Expression{ .function = .{ .name = "add", .args = &.{
        Expression{ .function = .{ .name = "add", .args = &.{ Expression{ .symbol = .{ .str = "a" } }, Expression{ .symbol = .{ .str = "b" } } } } },
        Expression{ .function = .{ .name = "mult", .args = &.{ Expression{ .symbol = .{ .str = "c" } }, Expression{ .symbol = .{ .str = "d" } } } } },
    } } };
    var add2 = Expression{ .function = .{ .name = "add", .args = &.{
        Expression{ .symbol = .{ .str = "a" } }, Expression{ .symbol = .{ .str = "b" } },
    } } };
    var add3 = Expression{ .function = .{ .name = "add", .args = &.{
        Expression{ .symbol = .{ .str = "x" } }, Expression{ .symbol = .{ .str = "y" } },
    } } };
    _ = add3;

    std.debug.print("add 1 is: {}, add 2 is: {}\n", .{ add1, add2 });

    //testing isPattern
    std.debug.print("{}\n", .{add1.isPattern(add2)});
    var mymap = stringmap.init(allocator);
    defer mymap.deinit();

    var expr_array: [7]Expression = undefined;
    _ = expr_array;

    //try add2.patternMatch(add3);
    //std.debug.print("{!}\n", .{addition_expr.apply(add3, &expr_array)});
    std.debug.print("{!}\n", .{addition_expr.apply(add1)});
    std.debug.print("{!}\n", .{multiply_expr.apply(add1)});
    //std.debug.print("{!}\n", .{addition_expr.apply(add2, &expr_array)});
}
