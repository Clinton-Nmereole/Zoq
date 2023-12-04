const std = @import("std");

const Lexer = @This();

index: comptime_int = 0,
identstart: comptime_int = 0,

pub const whitespace_chars: []const u8 = &[_]u8{
    ' ',
    '\t',
    '\n',
    '\r',
    std.ascii.control_code.vt,
    std.ascii.control_code.ff,
};

pub const identifier_characters: []const u8 =
    "ABCDEFGHIJKLMNOPQRSTUVWXYZ" ++
    "abcdefghijklmnopqrstuvwxyz" ++
    "0123456789" ++
    "_" //
;

//Utilities
pub inline fn eqlComptime(comptime T: type, comptime a: []const T, comptime b: []const T) bool {
    if (a.len != b.len) return false; //check if both arrays have the same length if they don't then they are not equal
    const len = a.len; // set a constant len to the length of the comptime array a
    const V = @Vector(len, T); //create a vector with a size of len and a type of T(the type of value stored in the comptime array a)
    // first we type coersion on the slice (a[0..] and b[0..]) to V(a vector of length len that holds values of type T)
    // then we check if both vectors are equal with "==" operator
    // Note that the "==" operator when used on vectors returns a new vector with boolean values of len equal to the vectors being compared.
    // So @Vector(4, u8){ 1, 2, 3, 4 } == @Vector(4, u8){ 1, 2, 3, 4 } returns @Vector(4, u8){true, true, true, true}
    // @Vector(4, u8){ 1, 2, 3, 4 } == @Vector(4, u8){ 1, 2, 8, 9 } returns @Vector(4, u8){true, true, false, false}
    // We however need to return a single boolean value, so we use @reduce.
    // All reduce does is perform a logical AND on the values of the vector returned by "==" operator
    // So Vector(4, u8){true, true, true, true} would become true because we use logical AND and it returns true when all the values are true
    // So @Vector(4, u8){true, true, true, false} if used with reduce and logical AND would return false
    comptime return @reduce(.And, @as(V, a[0..].*) == @as(V, b[0..].*));
}

//this takes in a type T and an array of anytype and returns a constant pointer to the array (a slice)
pub inline fn scalarSlice(
    comptime T: type,
    comptime array: anytype,
) *const [array.len]T {
    return &array;
}

pub fn indexOfNonePosComptime(
    comptime T: type,
    comptime haystack: anytype,
    comptime start: comptime_int,
    comptime excluded: anytype,
) ?comptime_int {
    if (@TypeOf(haystack) != [haystack.len]T) unreachable;
    const offs = indexOfNoneComptime(T, haystack[start..].*, excluded) orelse
        return null;
    return start + offs;
}

//this takes in a type T, and a haystack and excluded of types anytype and returns an optional comptime_int.
pub fn indexOfNoneComptime(
    comptime T: type,
    comptime haystack: anytype,
    comptime excluded: anytype,
) ?comptime_int {
    if (@TypeOf(haystack) != [haystack.len]T) unreachable;
    if (@TypeOf(excluded) != [excluded.len]T) unreachable;
    if (excluded.len == 0) unreachable;

    if (haystack.len == 0) return null;

    const len = haystack.len;

    var mask_bit_vec: @Vector(len, u1) = [_]u1{@intFromBool(true)} ** len;
    @setEvalBranchQuota(@min(std.math.maxInt(u32), (excluded.len + 1) * 100));
    for (excluded) |ex| {
        const ex_vec: @Vector(len, T) = @splat(ex);
        const match_bits: @Vector(len, u1) = @bitCast(haystack != ex_vec);
        mask_bit_vec &= match_bits;
    }

    const mask: std.meta.Int(.unsigned, len) = @bitCast(mask_bit_vec);
    const idx = @ctz(mask);
    return if (idx == haystack.len) null else idx;
}

pub inline fn containsScalarComptime(
    comptime T: type,
    comptime haystack: anytype,
    comptime needle: T,
) bool {
    comptime {
        if (@TypeOf(haystack) != [haystack.len]T) unreachable;
        const needle_vec: @Vector(haystack.len, T) = @splat(needle);
        const matches = haystack == needle_vec;
        return @reduce(.Or, matches);
    }
}

pub const Token = union(enum) {
    identifier: []const u8,
    number: []const u8,
    openParen,
    closeParen,
    comma,
    equals,
    eof: enum(comptime_int) {}, //Note this can be made into a regular enum value without being comptime.

    err: Err,

    pub const Err = union(enum(comptime_int)) {
        Unexpectedbyte: u8,
    };

    pub inline fn eql(comptime this: Token, comptime other: Token) bool {
        comptime if (std.meta.activeTag(this) != other) return false;

        return switch (this) {
            .comma, .openParen, .closeParen, .eof, .equals => true,
            inline .identifier, .number => |str, tag| eqlComptime(u8, str, @field(other, @tagName(tag))),
            .err => |err| err == other.err,
        };
    }

    pub inline fn format(
        comptime self: Token,
        comptime fmt_str: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) @TypeOf(writer).Error!void {
        _ = options;
        if (fmt_str.len != 0) comptime {
            std.fmt.invalidFmtError(fmt_str, self);
        };
        switch (self) {
            inline .identifier, .number => |str, tag| try writer.writeAll(comptime std.fmt.comptimePrint("{s}({s})", .{ @tagName(tag), str })),
            .comma, .openParen, .closeParen, .eof, .equals => try writer.writeAll(@tagName(self)),
            .err => |err| try writer.writeAll(comptime std.fmt.comptimePrint("{s}({s})", .{ @tagName(self), @tagName(err) })),
        }
    }
};

const PeekResult = struct {
    state: Lexer,
    token: Token,
};

fn peekImpl(
    comptime lexer_init: Lexer,
    comptime buffer: []const u8,
) PeekResult {
    if (!@inComptime()) comptime unreachable;
    const lexer = blk: {
        var lexer = lexer_init;
        switch ((buffer ++ [_:0]u8{})[lexer.index]) {
            ' ', '\t', '\n', '\r', std.ascii.control_code.vt, std.ascii.control_code.ff => {
                const whitespace_end = indexOfNonePosComptime(u8, buffer[0..].*, lexer.index + 1, whitespace_chars[0..].*) orelse buffer.len;
                lexer.index = whitespace_end;
                lexer.identstart = whitespace_end;
            },
            else => {},
        }
        break :blk lexer;
    };
    switch ((buffer ++ &[_:0]u8{})[lexer.index]) {
        0 => |sentinel| {
            if (lexer_init.index != buffer.len) return .{
                .state = .{ .index = lexer.index, .identstart = lexer.identstart },
                .token = .{ .err = .{ .unexpected_byte = sentinel } },
            };
            return .{
                .state = lexer,
                .token = .eof,
            };
        },

        ' ',
        '\t',
        '\n',
        '\r',
        std.ascii.control_code.vt,
        std.ascii.control_code.ff,
        => unreachable,

        ',', '(', ')', '=' => |char| return .{
            .state = .{ .index = lexer.index + 1, .identstart = lexer.identstart + 1 },
            .token = switch (char) {
                ',' => .comma,
                '(' => .openParen,
                ')' => .closeParen,
                '=' => .equals,
                else => unreachable,
            },
        },

        'a'...'z',
        'A'...'Z',
        '_',
        => {
            const start = lexer.index;
            const end = indexOfNonePosComptime(u8, buffer[0..].*, start + 1, identifier_characters[0..].*) orelse buffer.len;
            const ident = scalarSlice(u8, buffer[start..end].*);
            return .{
                .state = .{ .index = end, .identstart = start },
                .token = .{ .identifier = ident },
            };
        },
        '0'...'9' => {
            const start = lexer.index;
            @setEvalBranchQuota(@min(std.math.maxInt(u32), (buffer.len - start) * 100));
            var zig_lexer = std.zig.Tokenizer.init(buffer[start..] ++ &[_:0]u8{});
            const zig_tok = zig_lexer.next();

            if (zig_tok.loc.start != 0) unreachable;
            const literal_src = scalarSlice(u8, buffer[start..][zig_tok.loc.start..zig_tok.loc.end].*);

            return .{
                .state = .{ .index = start + literal_src.len, .identstart = start },
                .token = .{ .number = literal_src },
            };
        },
        else => |char| return .{
            .state = .{ .index = lexer.index + 1, .identstart = lexer.identstart + 1 },
            .token = .{ .err = .{ .Unexpectedbyte = char } },
        },
    }
    return null;
}

pub inline fn next(
    comptime lexer: *Lexer,
    comptime buffer: []const u8,
) Token {
    comptime {
        const result = lexer.peekImpl(scalarSlice(u8, buffer[0..].*));
        lexer.* = result.state;
        return result.token;
    }
}

pub inline fn peek(
    comptime lexer: *Lexer,
    comptime buffer: []const u8,
) Token {
    comptime {
        const result = lexer.peekImpl(scalarSlice(u8, buffer[0..].*));
        return result.token;
    }
}

fn testLexer(
    comptime buffer: []const u8,
    comptime expected: []const Token,
) !void {
    comptime var lexer = Lexer{};
    inline for (expected) |expected_token| {
        const actual_token = lexer.next(buffer);
        comptime if (actual_token.eql(expected_token)) continue;
        std.log.err("Expected '{}', got '{}'", .{ expected_token, actual_token }); //changing the value of eof would require the use of comptime print not just std.log.err
        return error.TestExpectedEqual;
    }
    const expected_token: Token = .eof;
    const actual_token = lexer.next(buffer);
    if (!expected_token.eql(actual_token)) {
        std.log.err("Expected '{}', got '{}'", .{ expected_token, actual_token });
        return error.TestExpectedEqual;
    }
}

fn test_idx(
    comptime buffer: []const u8,
) comptime_int {
    comptime var lexer = Lexer{};
    comptime var actual_token = lexer.next(buffer);
    inline while (actual_token != .eof) {
        actual_token = lexer.next(buffer);
    }
    comptime {
        return lexer.index;
    }
}

test "lexer" {
    const mytoken = Token{
        .identifier = "test",
    };
    const mytoken2 = Token{
        .identifier = "test",
    };
    const mytoken3 = Token{
        .identifier = "wrongtest",
    };
    try std.testing.expect(mytoken.eql(mytoken2) == true);
    try std.testing.expect(mytoken.eql(mytoken3) == false);
}

test "index" {
    try std.testing.expect(test_idx("test(able)") == 10);
}

test Lexer {
    try testLexer("add(a,b)", &.{
        .{ .identifier = "add" },
        .openParen,
        .{ .identifier = "a" },
        .comma,
        .{ .identifier = "b" },
        .closeParen,
    });

    try testLexer("mult(a, b)", &.{
        .{ .identifier = "mult" },
        .openParen,
        .{ .identifier = "a" },
        .comma,
        .{ .identifier = "b" },
        .closeParen,
    });

    try testLexer("div(f(a), b)", &.{
        .{ .identifier = "div" },
        .openParen,
        .{ .identifier = "f" },
        .openParen,
        .{ .identifier = "a" },
        .closeParen,
        .comma,
        .{ .identifier = "b" },
        .closeParen,
    });

    try testLexer("square(a)", &.{
        .{ .identifier = "square" },
        .openParen,
        .{ .identifier = "a" },
        .closeParen,
    });

    try testLexer("power(a, 2)", &.{
        .{ .identifier = "power" },
        .openParen,
        .{ .identifier = "a" },
        .comma,
        .{ .number = "2" },
        .closeParen,
    });
}
