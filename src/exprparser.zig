const std = @import("std");
const Token = @import("tokenizer.zig").Token;
const TokenType = @import("tokenizer.zig").TokenType;
const Lexer = @import("tokenizer.zig").Lexer;
const Expression = @import("expression.zig").Expression;
const Zoq = @import("expression.zig");
const Rule = @import("expression.zig").Rule;
const sym = Zoq.sym;
const fun = Zoq.fun;
//var gpa = std.heap.GeneralPurposeAllocator(.{}){};
var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const allocator = gpa.allocator();
const swap_expr1 = Zoq.swap_expr;

const keywordset = [_]Token{
    Token{ .token_type = .Apply, .value = "apply" },
    Token{ .token_type = .Shape, .value = "shape" },
    Token{ .token_type = .Rule, .value = "rule" },
    Token{ .token_type = .Quit, .value = "quit" },
    Token{ .token_type = .Done, .value = "done" },
};

const operatorset = [_]TokenType{
    .Plus,
    .Minus,
    .Multiply,
    .Divide,
    .Power,
};

pub fn parsesym(lexer: *Lexer) !Expression {
    var token = lexer.next();
    if (token.token_type == .identifier) {
        return .{ .symbol = .{ .str = token.value } };
    }
    return error.NotASymbol;
}

pub fn applyswap(a: Expression) !Expression {
    if (a.isFunction()) {
        return swap_expr1.apply_all(a);
    }
    return error.NotAFunction;
}

pub fn parseexpr(lexer: *Lexer, string_allocator: std.mem.Allocator) !Expression {
    var name = lexer.next();
    if (!name.token_type.iseql(.eof)) {
        switch (name.token_type) {
            .identifier => {
                var open = lexer.nextIf(.open_paren);
                if (open != null) {
                    var args: std.ArrayList(Expression) = std.ArrayList(Expression).init(allocator);
                    var close = lexer.nextIf(.close_paren);
                    if (close != null) {
                        //var fun_name = try string_allocator.dupe(u8, name.value);
                        return Zoq.fun(try string_allocator.dupe(u8, name.value), args.items);
                    }
                    var appen1 = try parseexpr(lexer, string_allocator);
                    try args.append(appen1);
                    //_ = lexer.nextIf(.comma);
                    while (lexer.nextIf(.comma) != null) {
                        var appen2 = try parseexpr(lexer, string_allocator);
                        try args.append(appen2);
                    }
                    if (lexer.nextIf(.close_paren) == null) {
                        return error.ExpectedCloseParen;
                    }
                    //var fun_name = try string_allocator.dupe(u8, name.value);
                    return Zoq.fun(try string_allocator.dupe(u8, name.value), args.items);
                } else {
                    //var sym_name = try string_allocator.dupe(u8, name.value);
                    return Zoq.sym(try string_allocator.dupe(u8, name.value));
                }
            },
            .number => {
                //var sym_name = try string_allocator.dupe(u8, name.value);
                return Zoq.sym(try string_allocator.dupe(u8, name.value));
            },
            else => {
                return error.NotAnExpression;
            },
        }
    } else {
        return error.MalformedExpression;
    }
}

pub fn parseRule(lexer: *Lexer, string_allocator: std.mem.Allocator) !Rule {
    var rule_expr = try parseexpr(lexer, string_allocator);
    _ = lexer.nextIf(.equals);
    var rule_equiv = try parseexpr(lexer, string_allocator);
    return .{
        .expression = rule_expr,
        .equivalent = rule_equiv,
    };
}

pub fn parseStatement(lexer: *Lexer) !f64 {
    var lhs = lexer.next();
    var Op = lexer.nextIfIn(&operatorset);
    var rhs = lexer.next();
    var lhs2 = try lhs.floatify();
    var rhs2 = try rhs.floatify();
    return switch (Op.?.token_type) {
        .Plus => lhs2 + rhs2,
        .Minus => lhs2 - rhs2,
        .Multiply => lhs2 * rhs2,
        .Divide => lhs2 / rhs2,
        .Power => std.math.pow(f64, lhs2, rhs2),
        else => error.NotAnOperator,
    };
}

pub fn parseRuleFromFile(filename: []const u8) !std.StringHashMap(Rule) {
    var rules_table = std.StringHashMap(Rule).init(allocator);
    var file = try std.fs.cwd().openFile(filename, .{});
    defer file.close();
    var buf = file.reader();
    var msg_buf: [4096]u8 = undefined;
    const message = try buf.readUntilDelimiterOrEof(&msg_buf, '\r');
    var lexer = Lexer.init(message.?);
    while (lexer.peek().token_type != .eof) {
        _ = lexer.nextIf(.Rule);
        var name = lexer.nextIf(.identifier);
        //_ = lexer.nextIf(.colon);
        var rule = try parseRule(&lexer);
        try rules_table.put(name.?.value, rule);
    }
    return rules_table;
}

pub fn bufferedReader(stream: anytype) std.io.BufferedReader(4096, @TypeOf(stream)) {
    return .{ .unbuffered_reader = stream };
}

pub fn bufferedWriter(stream: anytype) std.io.BufferedWriter(4096, @TypeOf(stream)) {
    return .{ .unbuffered_writer = stream };
}

pub const Context = struct {
    rules_table: std.StringArrayHashMap(Rule),
    expression_list: std.ArrayList(Expression),
    current_expr: ?Expression,
    alloctor: std.mem.Allocator,
    quit: bool = false,

    pub fn init(alloctor: std.mem.Allocator) Context {
        return .{ .rules_table = std.StringArrayHashMap(Rule).init(alloctor), .current_expr = null, .alloctor = alloctor, .expression_list = std.ArrayList(Expression).init(alloctor) };
    }

    pub fn get_rules_table(self: Context) std.StringArrayHashMap(Rule) {
        return self.rules_table;
    }

    pub fn put_rule(self: *Context, key: []const u8, value: Rule) !void {
        var dupe_key: []const u8 = try self.alloctor.dupe(u8, key[0..]);
        try self.rules_table.put(dupe_key, value);
    }

    pub fn get_rule(self: Context, key: []const u8) ?Rule {
        return self.rules_table.get(key);
    }

    pub fn deinit(self: *Context) void {
        var iter = self.rules_table.iterator();
        while (iter.next()) |kv| {
            self.alloctor.free(kv.key_ptr.*);
            //std.debug.print("{s}\n", .{kv.value_ptr.*});
        }
        self.rules_table.deinit();
    }

    pub fn get_current_expr(self: *Context) ?Expression {
        return self.current_expr;
    }

    pub fn set_current_expr(self: *Context, expr: ?Expression) void {
        self.current_expr = expr;
    }

    pub fn show_rules(self: *Context) void {
        const table = self.get_rules_table();
        var it = table.iterator();
        while (it.next()) |kv| {
            std.debug.print("{s}: {any} = {any}\n", .{ kv.key_ptr.*, kv.value_ptr.expression, kv.value_ptr.* });
        }
    }

    pub fn process_command(self: *Context, lexer: *Lexer) !void {
        var peeked = lexer.next();

        switch (peeked.token_type) {
            .Rule => {
                var rule_name = lexer.nextIf(.identifier);
                if (self.get_rule(rule_name.?.value) != null) {
                    return error.DuplicateRule;
                }
                //var rule = try parseRule(lexer);
                var head = try parseexpr(lexer, self.alloctor);
                _ = lexer.nextIf(.equals);
                var body = try parseexpr(lexer, self.alloctor);
                var rule = Rule{ .expression = head, .equivalent = body };
                std.debug.print("defined rule: {any}\n", .{&rule});
                try self.put_rule(rule_name.?.value, rule);
                self.show_rules();
            },
            .Shape => {
                if (self.get_current_expr() != null) {
                    return error.AlreadyShapingExpression;
                }
                var expr = try parseexpr(lexer, self.alloctor);
                std.debug.print("Shaping expression: {any}\n", .{expr});
                std.debug.print("\n", .{});
                self.set_current_expr(expr);
            },
            .Apply => {
                if (self.current_expr == null) {
                    return error.NoShapingInProgress;
                }
                var name = lexer.nextIf(.identifier);
                var rule_name: []const u8 = name.?.value;
                std.debug.print(" applying rule: {s}\n", .{rule_name});
                var rule = self.rules_table.get(rule_name);
                self.expression_list.append(self.current_expr.?) catch return error.OutOfMemory;
                self.current_expr = try rule.?.apply_all(self.current_expr.?, self.alloctor);
                std.debug.print(" new expression: {any}\n", .{self.current_expr});
                std.debug.print("\n", .{});
                if (rule == null) {
                    return error.RuleNotFound;
                }
            },
            .Done => {
                std.debug.print("current expression: {any}\n", .{self.current_expr});
                if (self.get_current_expr() != null) {
                    std.debug.print("done shaping: {any}\n", .{self.current_expr});
                    std.debug.print("\n", .{});
                    //self.current_expr.?.deinit();
                    self.set_current_expr(null);
                } else {
                    return error.NoShapingInProgress;
                }
            },
            .Quit => {
                self.quit = true;
                //self.deinit();
            },
            .Undo => {
                if (self.expression_list.items.len == 0) {
                    return error.NoExpressionToUndo;
                }
                self.current_expr = self.expression_list.pop();
                std.debug.print("undo shaping: {any}\n", .{self.current_expr});
                std.debug.print("\n", .{});
            },
            .Eval => {
                var stat = try parseStatement(lexer);
                std.debug.print("statement: {d:4}\n", .{stat});
            },
            else => {
                std.debug.print("unexpected token: {any}, expected token in set: {any}\n", .{ peeked, keywordset });
            },
        }
    }
};

pub fn main() !void {}
