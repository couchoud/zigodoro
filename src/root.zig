const std = @import("std");
const ansi = @import("./ansi.zig").ansi;

pub const TimeStruct = struct { minutes: u8, seconds: u8 };
pub const TimerError = error{ InvalidTimeFormat, MaxDurationExceeded };

const MAX_ALLOWED_SECONDS = 3600;

pub fn runTimer(stamp: []const u8, io: std.Io, writer: *std.Io.Writer) !void {
    const duration = try parseAndValidateTime(stamp);
    const duration_seconds = try convertTimeStructToSeconds(duration);
    const start = std.Io.Clock.now(.awake, io);
    var remaining_seconds: u64 = std.math.maxInt(u64);
    try ansi.clear.screen(writer);
    try ansi.cursor.hide(writer);
    try writeClock(writer, duration_seconds);
    while (remaining_seconds != 0) {
        try io.sleep(.fromSeconds(1), .awake);
        const now = start.untilNow(io, .awake);
        const now_seconds: u64 = @intCast(now.toSeconds());
        remaining_seconds = duration_seconds - now_seconds;
        try writeClock(writer, remaining_seconds);
    }
}

fn writeClock(writer: *std.Io.Writer, seconds: u64) !void {
    const ms = try convertSecondsToTimeStruct(seconds);
    try writer.print("Time Remaining: {:0>2}:{:0>2}\r", ms);
    try writer.flush();
}

fn convertSecondsToTimeStruct(total_seconds: u64) !TimeStruct {
    const minutes = (total_seconds % 3600) / 60;
    const seconds = (total_seconds % 60);

    return .{ .minutes = @intCast(minutes), .seconds = @intCast(seconds) };
}

fn convertTimeStructToSeconds(ms: TimeStruct) !u64 {
    const min_seconds = ms.minutes * @as(u64, std.time.s_per_min);
    return min_seconds + ms.seconds;
}

fn validateMinutes(minutes: u64) !void {
    const seconds = minutes * 60;
    return validateSeconds(seconds);
}

fn validateSeconds(interval: u64) !void {
    if (interval > MAX_ALLOWED_SECONDS)
        return TimerError.MaxDurationExceeded;
}

fn parseAndValidateTime(time_str: []const u8) !TimeStruct {
    if (time_str.len != 5) return TimerError.InvalidTimeFormat;
    if (time_str[2] != ':') return TimerError.InvalidTimeFormat;

    const min_str = time_str[0..2];
    const sec_str = time_str[3..5];

    const minutes = std.fmt.parseInt(u8, min_str, 10) catch return TimerError.InvalidTimeFormat;
    const seconds = std.fmt.parseInt(u8, sec_str, 10) catch return TimerError.InvalidTimeFormat;

    if (minutes > 59) return TimerError.InvalidTimeFormat;
    if (seconds > 59) return TimerError.InvalidTimeFormat;

    return TimeStruct{ .minutes = minutes, .seconds = seconds };
}
