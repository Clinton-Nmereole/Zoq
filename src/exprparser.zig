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

pub fn getUserExpr() !void {
    const stdin = std.io.getStdIn().reader();
    const stdout = std.io.getStdOut().writer();

    var buf: [2048]u8 = undefined;
    try stdout.print("Enter an expression: ", .{});
    if (stdin.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        const line2 = line.?;
        var lexer2 = Lexer.init(line2);
        var expr3 = parseexpr(&lexer2);
        if (expr3) |expr| {
            try stdout.print("{}\n", .{expr});
        } else |err| {
            try stdout.print("error: {any}\n", .{err});
        }
    } else |err| {
        try stdout.print("error: {any}\n", .{err});
    }
}

pub fn bufferedReader(stream: anytype) std.io.BufferedReader(4096, @TypeOf(stream)) {
    return .{ .unbuffered_reader = stream };
}

pub fn bufferedWriter(stream: anytype) std.io.BufferedWriter(4096, @TypeOf(stream)) {
    return .{ .unbuffered_writer = stream };
}

pub fn getUserExprBuffered() !void {
    const in = std.io.getStdIn();
    const out = std.io.getStdOut();
    var buf = bufferedReader(in.reader());
    var buf2 = bufferedWriter(out.writer());
    var w = buf2.writer();

    var r = buf.reader();
    std.debug.print("Zoq> ", .{});

    var msg_buf: [4096]u8 = undefined;
    var msg = r.readUntilDelimiterOrEof(&msg_buf, '\n');
    if (msg) |m| {
        const m2 = m.?;
        var lexer2 = Lexer.init(m2);
        var expr3 = parseexpr(&lexer2);
        if (expr3) |expr| {
            try w.print("{}\n", .{expr});
        } else |err| {
            try w.print("error: {any}\n", .{err});
        }
    } else |err| {
        try w.print("\n", .{});
        try w.print("error: {any}\n", .{err});
    }

    try w.print("\n", .{});
    try buf2.flush();
}

pub fn getUserExprBufferedInput() !?[]u8 {
    const in = std.io.getStdIn();
    var buf = bufferedReader(in.reader());

    var r = buf.reader();
    std.debug.print("Zoq> ", .{});

    var msg_buf: [4096]u8 = undefined;
    var msg = r.readUntilDelimiterOrEof(&msg_buf, '\n');
    return msg;
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
        std.debug.print("Zoq> ", .{});

        var msg_buf: [4096]u8 = undefined;
        var msg = r.readUntilDelimiterOrEof(&msg_buf, '\n');
        if (msg) |m| {
            const m2 = m.?;
            var lexer2 = Lexer.init(m2);
            var expr3 = parseexpr(&lexer2);
            if (expr3) |expr| {
                try w.print("{}\n", .{expr});
            } else |err| {
                if (err == error.Quit) {
                    quit = true;
                }
                try w.print("error: {any}\n", .{err});
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

    //var peeked = lexer.peek();
    //std.debug.print("peeked: {s}\n", .{peeked.value});
    //next = lexer.next();
    //std.debug.print("{}\n", .{lexer});
    //var expr = try parsesym(&lexer);
    //std.debug.print("parsed symbol: {}\n", .{expr});
    var expr2 = try parseexpr(&lexer);
    std.debug.print("parsed expression: {}\n", .{expr2});
    //std.debug.print("Type of expression is: {s}\n", .{@tagName(expr2)});
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
    try interact();
    //try getUserExprBuffered();
    //var k = try getUserExprBufferedInput();
    //std.debug.print("k: {s}\n", .{k.?});
}
