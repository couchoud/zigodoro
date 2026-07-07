const std = @import("std");
const ansi = @import("./ansi.zig").ansi;

pub const TimeStruct = struct { minutes: u8, seconds: u8 };
const TimerState = enum { idle, running, paused };

pub const Timer = struct {
    duration: i64 = 0,
    remaining: i64 = 0,
    state: TimerState = TimerState.idle,
    io: std.Io,
    progress: *const fn (i64) anyerror!void,
    pub fn start(self: *Timer, seconds: i64) !void {
        self.duration = @intCast(seconds);
        const start_time = std.Io.Clock.now(.awake, self.io);
        self.remaining = std.math.maxInt(i64);
        self.state = TimerState.running;
        while (self.state == .running) {
            if (self.remaining == 0) {
                self.state = TimerState.idle;
            } else if (self.state != TimerState.paused) {
                try self.io.sleep(.fromSeconds(1), .awake);
                const now = start_time.untilNow(self.io, .awake);
                const now_seconds: i64 = @intCast(now.toSeconds());
                self.remaining = self.duration - now_seconds;
                try self.progress(self.remaining);
            }
        }
    }
    pub fn stop(self: *Timer) void {
        self.state = TimerState.idle;
        self.remaining = undefined;
    }
    pub fn pause(self: *Timer) void {
        if (self.state == .running) {
            self.state = .paused;
        } else if (self.state == TimerState.paused) {
            self.state = .running;
        }
    }
};
