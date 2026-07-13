const std = @import("std");
const Io = std.Io;

const day_seconds = std.time.epoch.DaySeconds;
const heap = std.heap;
const clock = std.Io.Clock;
const epoch_seconds = std.time.epoch.EpochSeconds;
const day_epoch_seconds = std.time.epoch.DaySeconds;
const epoch_day = std.time.epoch.EpochDay;
const epoch_year_day = std.time.epoch.YearAndDay;

const TimeParts = struct { year: u16, month: u4, day: u5 };

pub fn getTimeParts(io: std.Io) !TimeParts {
    const timestamp = std.Io.Clock.now(.real, io);
    const sec = std.Io.Timestamp.toSeconds(timestamp);
    const sec_u: u64 = @intCast(sec);

    const day = epoch_seconds.getEpochDay(epoch_seconds{ .secs = sec_u });
    const yr_day = epoch_day.calculateYearDay(day);
    const mon_day = epoch_year_day.calculateMonthDay(yr_day);

    return TimeParts{ .year = yr_day.year, .month = mon_day.month.numeric() + 1, .day = mon_day.day_index + 1 };
}
