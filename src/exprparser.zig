const std = @import("std");
const Token = @import("tokenizer.zig").Token;
const Lexer = @import("tokenizer.zig").Lexer;
const Expression = @import("expression.zig").Expression;
const Zoq = @import("expression.zig");
const Rule = Zoq.Rule;
const sym = Zoq.sym;
const fun = Zoq.fun;
var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const allocator = gpa.allocator();
const tokenize = std.mem.tokenizeAny;
const stringmap = std.StringHashMap(Rule);

const swap_expr1 = Zoq.swap_expr;

pub fn parsesym(lexer: *Lexer) !Expression {
    var token = lexer.next();
    if (token.token_type == .identifier) {
        return .{ .symbol = .{ .str = token.value } };
    }
    return error.NotASymbol;
}

pub fn applyswap(a: Expression) !Expression {
    if (a.isFunction()) {
        return swap_expr1.apply(a);
    }
    return error.NotAFunction;
}

pub fn parseexpr(lexer: *Lexer) !Expression {
    var name = lexer.next();
    if (!name.token_type.iseql(.eof)) {
        switch (name.token_type) {
            .identifier => {
                var open = lexer.nextIf(.open_paren);
                if (open != null) {
                    var args: std.ArrayList(Expression) = std.ArrayList(Expression).init(allocator);
                    var close = lexer.nextIf(.close_paren);
                    if (close != null) {
                        var fun_name = name.value;
                        return Zoq.fun(fun_name, args.items);
                    }
                    var appen1 = try parseexpr(lexer);
                    try args.append(appen1);
                    //_ = lexer.nextIf(.comma);
                    while (lexer.nextIf(.comma) != null) {
                        var appen2 = try parseexpr(lexer);
                        try args.append(appen2);
                    }
                    if (lexer.nextIf(.close_paren) == null) {
                        return error.ExpectedCloseParen;
                    }
                    var fun_name = name.value;
                    return Zoq.fun(fun_name, args.items);
                } else {
                    var sym_name = name.value;
                    return Zoq.sym(sym_name);
                }
            },
            .number => {
                var sym_name = name.value;
                return Zoq.sym(sym_name);
            },
            .Apply => {
                var appen = try parseexpr(lexer);
                return applyswap(appen);
            },
            .Quit => {
                return error.Quit;
            },
            else => {
                return error.NotAnExpression;
            },
        }
    } else {
        return error.MalformedExpression;
    }
}

pub fn parseRule(lexer: *Lexer) !Rule {
    var rule_expr = try parseexpr(lexer);
    _ = lexer.nextIf(.equals);
    var rule_equiv = try parseexpr(lexer);
    return Rule{
        .expression = rule_expr,
        .equivalent = rule_equiv,
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

pub fn interact() !void {
    var quit: bool = false;
    while (!quit) {
        const in = std.io.getStdIn();
        const out = std.io.getStdOut();
        var buf = bufferedReader(in.reader());
        var buf2 = bufferedWriter(out.writer());
        var w = buf2.writer();

        var r = buf.reader();
        std.debug.print("Zoq::> ", .{});

        var msg_buf: [4096]u8 = undefined;
        var msg = r.readUntilDelimiterOrEof(&msg_buf, '\n');
        if (msg) |m| {
            const m2 = m.?;
            var lexer2 = Lexer.init(m2);
            if (lexer2.peek().token_type == .Rule) {
                _ = lexer2.next();
                var rule = try parseRule(&lexer2);
                try w.print("{}\n", .{rule});
            } else {
                var expr3 = parseexpr(&lexer2);
                if (expr3) |expr| {
                    try w.print("{}\n", .{expr});
                } else |err| {
                    if (err == error.Quit) {
                        quit = true;
                    } else {
                        try w.print("error: {any}\n", .{err});
                    }
                }
            }
        } else |err| {
            try w.print("\n", .{});
            try w.print("error: {any}\n", .{err});
        }

        try w.print("\n", .{});
        try buf2.flush();
    }
}

pub fn main() !void {
    const buffer = "swap(pair(a,b))";
    var lexer = Lexer.init(buffer);
    var expr2 = try parseexpr(&lexer);
    std.debug.print("parsed expression: {}\n", .{expr2});
    const addition_expr = Rule{
        .expression = fun("add", &.{ sym("a"), sym("b") }),
        .equivalent = fun("add", &.{ sym("b"), sym("a") }),
    };

    const swap_expr = Rule{
        .expression = fun("swap", &.{fun("pair", &.{ sym("a"), sym("b") })}),
        .equivalent = fun("pair", &.{ sym("b"), sym("a") }),
    };
    std.debug.print("swap expression applied: {!}\n", .{addition_expr.apply(expr2)});
    std.debug.print("swap expression applied: {!}\n", .{swap_expr.apply(expr2)});
    //try interact();

    //const myrule = "swap(pair(a,b)) = pair(b,a)";
    //var lexer2 = Lexer.init(myrule);
    //var expr3 = try parseRule(&lexer2);
    //std.debug.print("parsed rule: {}\n", .{expr3});
    //
    const default_file = "rules.zoq";
    var rule_list = try parseRuleFromFile(default_file);
    var rule_iter = rule_list.iterator();
    std.debug.print("number of rules: {}\n", .{rule_list.count()});
    while (rule_iter.next()) |rule| {
        std.debug.print("rule name: {s}, the rule states: {s}\n", .{ rule.key_ptr.*, rule.value_ptr.* });
    }
}
