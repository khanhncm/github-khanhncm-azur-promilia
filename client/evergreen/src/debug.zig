var __wine_dbg_write: ?*const fn (str: [*:0]const u8, len: usize) callconv(.winapi) void = null;

pub fn init() void {
    if (GetProcAddress(GetModuleHandleA("ntdll.dll"), "__wine_dbg_write")) |ptr| {
        __wine_dbg_write = @ptrCast(ptr);
    }
}

pub fn log(
    comptime level: std.log.Level,
    comptime scope: @EnumLiteral(),
    comptime format: []const u8,
    args: anytype,
) void {
    if (__wine_dbg_write == null) return std.log.defaultLog(level, scope, format, args);

    setColor(switch (level) {
        .err => .red,
        .warn => .yellow,
        .info => .green,
        .debug => .magenta,
    });
    setColor(.bold);
    print(level.asText(), .{});
    setColor(.reset);
    setColor(.dim);
    setColor(.bold);
    if (scope != .default) print("({t})", .{scope});
    print(": ", .{});
    setColor(.reset);
    print(format ++ "\n", args);
}

fn print(comptime fmt: []const u8, args: anytype) void {
    if (std.meta.fields(@TypeOf(args)).len == 0) return __wine_dbg_write.?(@ptrCast(fmt), fmt.len);

    const str = std.fmt.allocPrintSentinel(gpa, fmt, args, 0) catch return;
    defer gpa.free(str);

    __wine_dbg_write.?(str, str.len);
}

fn setColor(comptime color: Color) void {
    print(switch (color) {
        .black => "\x1b[30m",
        .red => "\x1b[31m",
        .green => "\x1b[32m",
        .yellow => "\x1b[33m",
        .blue => "\x1b[34m",
        .magenta => "\x1b[35m",
        .cyan => "\x1b[36m",
        .white => "\x1b[37m",
        .bright_black => "\x1b[90m",
        .bright_red => "\x1b[91m",
        .bright_green => "\x1b[92m",
        .bright_yellow => "\x1b[93m",
        .bright_blue => "\x1b[94m",
        .bright_magenta => "\x1b[95m",
        .bright_cyan => "\x1b[96m",
        .bright_white => "\x1b[97m",
        .bold => "\x1b[1m",
        .dim => "\x1b[2m",
        .reset => "\x1b[0m",
    }, .{});
}

extern "kernel32" fn GetModuleHandleA(lpModuleName: ?windows.LPCSTR) callconv(.winapi) windows.HMODULE;
extern "kernel32" fn GetProcAddress(hModule: windows.HMODULE, lpProcName: windows.LPCSTR) callconv(.winapi) ?windows.FARPROC;
extern "kernel32" fn AllocConsole() callconv(.winapi) void;

const gpa = std.heap.page_allocator;

const Color = std.Io.Terminal.Color;
const windows = std.os.windows;

const std = @import("std");
