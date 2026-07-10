const std = @import("std");
const EventDispatcher = @import("./event_dispatcher.zig").EventDispatcher;

pub const TimeStruct = struct { minutes: u8, seconds: u8 };
const TimerState = enum { idle, running, paused };

pub const Timer = struct {
    duration: i64 = 0,
    remaining: i64 = 0,
    state: TimerState = TimerState.idle,
    io: std.Io,
    dispatcher: *EventDispatcher,
    pub fn start(self: *Timer, seconds: i64) !void {
        self.duration = @intCast(seconds);
        self.remaining = @intCast(seconds);
        const start_time = std.Io.Clock.now(.awake, self.io);
        self.state = TimerState.running;
        self.dispatcher.dispatch("progress");
        while (self.state == .running) {
            if (self.remaining == 0) {
                self.state = TimerState.idle;
            } else if (self.state != TimerState.paused) {
                try self.io.sleep(.fromSeconds(1), .awake);
                const now = start_time.untilNow(self.io, .awake);
                const now_seconds: i64 = @intCast(now.toSeconds());
                self.remaining = self.duration - now_seconds;
                self.dispatcher.dispatch("progress");
            }
        }
    }
    pub fn stop(self: *Timer) void {
        self.dispatcher.dispatch("stop");
        self.state = TimerState.idle;
        self.remaining = undefined;
    }
    pub fn pause(self: *Timer) void {
        if (self.state == .running) {
            self.state = .paused;
        } else if (self.state == TimerState.paused) {
            self.state = .running;
        }
        self.dispatcher.dispatch("pause");
    }
};
