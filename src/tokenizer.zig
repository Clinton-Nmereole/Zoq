const std = @import("std");

pub const identifier_characters: []const u8 =
    "ABCDEFGHIJKLMNOPQRSTUVWXYZ" ++
    "abcdefghijklmnopqrstuvwxyz" ++
    "_" //
;

pub const whitespace_chars: []const u8 = &[_]u8{
    ' ',
    '\t',
    '\n',
    '\r',
    std.ascii.control_code.vt,
    std.ascii.control_code.ff,
};

pub fn isIdentifierChar(char: u8) bool {
    return std.mem.indexOfScalar(u8, identifier_characters, char) != null;
}

pub const TokenType = union(enum) {
    Quit,
    Shape,
    Apply,
    identifier,
    comma,
    equals,
    open_paren,
    close_paren,
    eof,
    err: Errer,

    pub const Errer = union(enum) {
        unexpected_byte: u8,
    };

    pub fn iseql(a: TokenType, b: TokenType) bool {
        return if (std.meta.activeTag(a) == std.meta.activeTag(b)) true else false;
    }
};

pub fn keyword(name: []const u8) ?TokenType {
    const case = enum {
        quit,
        shape,
        apply,
    };
    const cmd = std.meta.stringToEnum(case, name) orelse return null;

    switch (cmd) {
        .quit => return TokenType{ .Quit = {} },
        .shape => return TokenType{ .Shape = {} },
        .apply => return TokenType{ .Apply = {} },
    }
}

pub const Token = struct {
    token_type: TokenType,
    value: []const u8,
};

pub const Lexer = struct {
    const Self = @This();
    buffer: []const u8,
    pos: usize,
    read_pos: usize,
    ch: u8,

    pub fn init(buffer: []const u8) Self {
        return Self{
            .pos = 0,
            .read_pos = 0,
            .ch = 0,
            .buffer = buffer,
        };
    }

    fn read(self: *Self) void {
        if (self.read_pos >= self.buffer.len) {
            self.ch = 0;
        } else {
            self.ch = self.buffer[self.read_pos];
        }
        self.pos = self.read_pos;
        self.read_pos += 1;
    }

    pub fn readPrev(self: *Self) void {
        self.read_pos -= 1;
        if (self.read_pos < 0) {
            self.ch = 0;
        } else {
            self.ch = self.buffer[self.read_pos];
        }
        self.pos -= 1;
    }

    pub fn peek(self: *Self) Token {
        const start = self.pos;
        const read_start = self.read_pos;
        const token = self.next();
        self.pos = start;
        self.read_pos = read_start;
        return token;
    }

    pub fn next(self: *Self) Token {
        self.read();
        const token = switch (self.ch) {
            ' ',
            '\t',
            '\n',
            '\r',
            std.ascii.control_code.vt,
            std.ascii.control_code.ff,
            => {
                while (std.mem.indexOfScalar(u8, whitespace_chars, self.ch) != null) self.read();
                self.read_pos = self.pos;
                self.pos -= 1;
                return self.next();
            },
            '=' => Token{
                .token_type = .equals,
                .value = "=",
            },
            ',' => Token{
                .token_type = .comma,
                .value = ",",
            },
            '(' => Token{
                .token_type = .open_paren,
                .value = "(",
            },
            ')' => Token{
                .token_type = .close_paren,
                .value = ")",
            },
            0 => Token{
                .token_type = .eof,
                .value = "eof",
            },
            'a'...'z', 'A'...'Z', '_' => {
                const start = self.pos;
                while (isIdentifierChar(self.ch)) self.read();
                const value = self.buffer[start..self.pos];
                self.read_pos = self.pos;
                self.pos -= 1;
                if (keyword(value)) |token_type| {
                    return Token{
                        .token_type = token_type,
                        .value = value,
                    };
                }
                return Token{
                    .token_type = .identifier,
                    .value = value,
                };
            },
            else => Token{
                .token_type = .{ .err = .{ .unexpected_byte = self.ch } },
                .value = "error",
            },
        };
        return token;
    }

    pub fn nextIf(self: *Self, token_type: TokenType) ?Token {
        if (self.peek().token_type.iseql(token_type)) {
            return self.next();
        }
        return null;
    }
};

pub fn main() !void {
    const buffer = "a()(,)";
    var lexer = Lexer.init(buffer);
    var next = lexer.next();
    //next = lexer.next();
    std.debug.print("{}\n", .{lexer});
    while (next.token_type != .eof) {
        std.debug.print("token type {?}, token value: {s}\n", .{ next.token_type, next.value });
        next = lexer.next();
    }
}

test "equal tokentype" {
    const a = TokenType{ .identifier = {} };
    const b = TokenType{ .identifier = {} };
    try std.testing.expect(a.iseql(b) == true);
}

test "equal2 tokentype" {
    const a = Token{ .token_type = .open_paren, .value = "(" };
    try std.testing.expect(a.token_type.iseql(.open_paren) == true);
}
