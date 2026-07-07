const std = @import("std");

pub const Cursor = struct {
    pub fn show(writer: *std.Io.Writer) !void {
        return try writer.writeAll("\x1b[?25h");
    }
    pub fn hide(writer: *std.Io.Writer) !void {
        return try writer.writeAll("\x1B[?25l");
    }
};

pub const Clear = struct {
    pub fn screen(writer: *std.Io.Writer) !void {
        return try writer.writeAll("\x1Bc");
    }
};

pub const ansi = struct {
    pub const cursor = Cursor;
    pub const clear = Clear;
};
