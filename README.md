# Zigodoro

Sort of like Pomodoro timer, but you enter tasks after completion and not before. 

I wanted a tool to track how I was spending my time. I also wanted to play around with Zig.

## Status: WIP - Half Working

Task timer/logger built in [zig](https://ziglang.org/).

```zig
build run

# or run with set time in MM:SS format

build run -- 00:05
```

1. Run the application with or without a time
1. Start the timer when ready
1. Enter a task when the timer runs out, which will be logged to a file
1. Restart the time or quit

## Current To-do's

- [ ] Write task to markdown file, e.g. tasks-20260101.md
- [ ] Time Input validation
- [ ] Pause Timer command
- [ ] Cancel Timer command
- [ ] Hide user stdin unless prompted
- [ ] Add tests
