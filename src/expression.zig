const std = @import("std");
var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const allocator = gpa.allocator();
const stringmap = std.StringHashMap(Expression);
const tokenize = std.mem.tokenizeAny;

pub const NoMatch = error{NO_MATCH};

//Declare a tagged union called an expression
//An expression can be a symbol, a function.
//A function has a name and a list of arguments
pub const Expression = union(enum) {
    symbol: struct { str: []const u8 },
    function: struct { name: []const u8, args: []const Expression },

    //This is wrong. It tries to use the gpa to free memory for an expression that might not contain strings allocated by the gpa allocator.
    pub fn deinit(self: *Expression) void {
        switch (self.*) {
            .symbol => |s| {
                allocator.free(s.str);
            },
            .function => |f| {
                allocator.free(f.name);
                allocator.free(f.args);
            },
        }
    }

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
            .symbol => 1,
            .function => |f| f.args.len + 1,
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
                .function => |f2| (std.mem.eql(u8, f.name, f2.name) and f.args.len == f2.args.len),
            },
        };
    }

    pub fn pattern_match(self: Expression, other: Expression, alloctor: std.mem.Allocator) !?std.StringHashMap(Expression) {
        var mymap = stringmap.init(alloctor);

        const Fns = struct {
            fn match_impl(self2: Expression, other2: Expression, amap: *stringmap) !bool {
                return switch (self2) {
                    .symbol => |s| switch (other2) {
                        .symbol => |_| {
                            if (!amap.contains(s.str)) {
                                try amap.put(s.str, other2);
                            } else {
                                var entry = amap.get(s.str).?;
                                if (!entry.eql(other2)) {
                                    if (amap.remove(s.str)) {
                                        return false;
                                    }
                                }
                            }
                            return true;
                        },
                        .function => |_| {
                            if (!amap.contains(s.str)) {
                                try amap.put(s.str, other2);
                            } else {
                                var entry = amap.get(s.str).?;
                                if (!entry.eql(other2)) {
                                    if (amap.remove(s.str)) {
                                        return false;
                                    }
                                }
                            }
                            return true;
                        },
                    },
                    .function => |f| switch (other2) {
                        .symbol => |_| {
                            try amap.put(f.name, other2);
                            return true;
                        },
                        .function => |f2| {
                            if (std.mem.eql(u8, f.name, f2.name) and f.args.len == f2.args.len) {
                                for (0..f.args.len) |i| {
                                    if (!try @This().match_impl(f.args[i], f2.args[i], amap)) {
                                        return false;
                                    }
                                }
                                return true;
                            } else {
                                return false;
                            }
                        },
                    },
                };
            }
        };

        if (try Fns.match_impl(self, other, &mymap)) {
            return mymap;
        } else {
            return null;
        }
    }
};

//NOTE: this function might later take in an allocator in order to use allocator.dupe so that expression always hold copies of strings and not pointers
pub inline fn sym(symbol_name: []const u8) Expression {
    return Expression{ .symbol = .{ .str = symbol_name } };
}

//NOTE: this function might later take in an allocator in order to use allocator.dupe so that expression always hold copies of strings and not pointers
pub inline fn fun(name: []const u8, args: []const Expression) Expression {
    return Expression{ .function = .{ .name = name, .args = args } };
}

fn append_expr(
    expr: Expression,
    list: []const Expression,
) []const Expression {
    var newlist = list;
    newlist = newlist ++ @as([]const Expression, &.{expr});
    return newlist;
}

pub fn substitute_bindings(expr: Expression, bindings: std.StringHashMap(Expression)) !Expression {
    var new_name: []const u8 = "";
    return switch (expr) {
        .symbol => |s| {
            var value = bindings.get(s.str);
            if (value != null) {
                return value.?;
            } else {
                return expr;
            }
        },
        .function => |f| {
            var value = bindings.get(f.name);
            if (value != null) {
                new_name = switch (bindings.get(f.name).?) {
                    .symbol => |s| s.str,
                    else => f.name,
                };
            } else {
                new_name = f.name;
            }
            var new_args = try allocator.alloc(Expression, f.args.len);
            for (f.args, 0..) |arg, i| {
                new_args[i] = try substitute_bindings(arg, bindings);
            }
            return Expression{ .function = .{ .name = new_name, .args = new_args } };
        },
    };
}

//A rule is a struct that has an expression and its equivalent
//A rule enforces that the expression and equivalent are the same
//i.e a + b ≡ b + a
pub const Rule = struct {
    expression: Expression,
    equivalent: Expression,

    pub fn deinit(self: *Rule) void {
        self.expression.deinit();
        self.equivalent.deinit();
    }

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

    pub fn apply_all(self: *Rule, expr: Expression, alloctor: std.mem.Allocator) !Expression {
        var bindings = try self.expression.pattern_match(expr, alloctor);
        if (bindings != null) {
            return substitute_bindings(self.equivalent, bindings.?);
        } else {
            switch (expr) {
                .symbol => |_| {
                    return expr;
                },
                .function => |f| {
                    var new_args = try alloctor.alloc(Expression, f.args.len);
                    for (f.args, 0..) |arg, i| {
                        new_args[i] = try self.apply_all(arg, alloctor);
                    }
                    return Expression{ .function = .{ .name = f.name, .args = new_args } };
                },
            }
        }
    }
};

//Some mathematical rules declarations
pub const swap_expr = Rule{
    .expression = fun("swap", &.{fun("pair", &.{ sym("a"), sym("b") })}),
    .equivalent = fun("pair", &.{ sym("b"), sym("a") }),
};

pub const ident = Rule{
    .expression = sym("x"),
    .equivalent = fun("add", &.{ sym("x"), sym("0") }),
};

pub const addition_expr = Rule{
    .expression = fun("add", &.{ sym("a"), sym("b") }),
    .equivalent = fun("add", &.{ sym("b"), sym("a") }),
};

pub const multiply_expr = Rule{
    .expression = fun("mult", &.{ sym("a"), sym("b") }),
    .equivalent = fun("mult", &.{ sym("b"), sym("a") }),
};

pub const division_expr = Rule{
    .expression = fun("div", &.{ sym("a"), sym("b") }),
    .equivalent = fun("mult", &.{ sym("a"), sym("1/b") }),
};

pub const square_expr = Rule{
    .expression = fun("square", &.{sym("a")}),
    .equivalent = fun("mult", &.{ sym("a"), sym("a") }),
};

pub const power_expr = Rule{
    .expression = fun("power", &.{ sym("a"), sym("n") }),
    .equivalent = fun("mult", &.{ sym("a"), fun("power", &.{ sym("a"), sym("n-1") }) }),
};

pub fn main() !void {
    var alloctor = allocator;
    var swap_expr1 = Rule{
        .expression = fun("swap", &.{fun("pair", &.{ sym("a"), sym("b") })}),
        .equivalent = fun("pair", &.{ sym("b"), sym("a") }),
    };

    var expr1 = fun("foo", &.{fun("swap", &.{fun("pair", &.{ sym("x"), sym("y") })})});
    var applied = try swap_expr1.apply_all(expr1, alloctor);
    std.debug.print("{any}\n", .{applied});
}

test "Symbol Equality" {
    try std.testing.expectEqual(sym("a"), sym("a"));
}

test "isPattern Function" {
    try std.testing.expect(fun("add", &.{ sym("x"), sym("y") }).isPattern(fun("add", &.{ sym("y"), sym("x") })) == true);
}

test "putinmap Function" {
    var mymap = stringmap.init(std.testing.allocator);
    defer mymap.deinit();
    const expr1 = fun("add", &.{ sym("x"), sym("y") });
    const expr2 = fun("add", &.{ sym("a"), sym("b") });
    try expr1.putinMap(expr2, &mymap);
    try std.testing.expect(mymap.count() == 2);
    try std.testing.expectEqual(mymap.get("x"), expr2.function.args[0]);
    try std.testing.expectEqual(mymap.get("y"), expr2.function.args[1]);
}

test "Rule apply" {
    var expr1 = fun("add", &.{ sym("x"), sym("y") });
    var expr2 = fun("add", &.{ sym("y"), sym("x") });
    var expr3 = try addition_expr.apply(expr1);
    try std.testing.expect(expr3.eql(expr2) == true);
}
