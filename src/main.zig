const std = @import("std");
const Token = @import("tokenizer.zig").Token;
const Lexer = @import("tokenizer.zig").Lexer;
const Expression = @import("expression.zig").Expression;
const Zoq = @import("expression.zig");
const Rule = Zoq.Rule;
const sym = Zoq.sym;
const fun = Zoq.fun;
const Parser = @import("exprparser.zig");
const bufferedReader = Parser.bufferedReader;
const bufferedWriter = Parser.bufferedWriter;
const parseRule = Parser.parseRule;
const parseexpr = Parser.parseexpr;
const Context = Parser.Context;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var prompt: []const u8 = "Zoq::> ";

    var context: Context = Context.init(allocator);
    defer context.deinit();
    while (true) {
        var r = std.io.getStdIn().reader();
        var w = std.io.getStdOut().writer();
        _ = w;
        var buf: [4096]u8 = undefined;
        var command: []const u8 = undefined;
        std.debug.print("{s}\n", .{prompt});
        var temp = try r.readUntilDelimiterOrEof(&buf, '\n');
        command = temp.?;
        var lexer = Lexer.init(command);
        var result = try context.process_command(&lexer);
        _ = result;
        //std.debug.print("{any}\n", .{context.rules_table});
    }
    context.show_rules();
}
