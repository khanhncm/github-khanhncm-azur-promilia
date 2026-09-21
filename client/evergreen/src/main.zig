pub const std_options: std.Options = .{
    .log_level = .debug,
    .logFn = debug.log,
};

pub fn main(init: process.Init) u8 {
    winapi.FreeConsole();
    debug.init();

    const unity_player = loadLibrary("UnityPlayer.dll");
    const game_assembly = loadLibrary("GameAssembly.dll");

    initPatches(@intFromPtr(game_assembly)) catch |err| fatal("failed to init patches: {t}", .{err});

    const UnityMain: *const fn (
        *winapi.HMODULE,
        ?*winapi.HMODULE,
        winapi.LPWSTR,
        i32,
    ) callconv(.c) void = @ptrCast(winapi.GetProcAddress(unity_player, "UnityMain"));

    if (std.Thread.spawn(.{}, struct {
        fn wait(io: std.Io) void {
            winapi.Sleep(250);
            winapi.AllocConsole();
            printDoro(io);
        }
    }.wait, .{init.io})) |t| {
        t.detach();
    } else |_| {
        winapi.AllocConsole();
        printDoro(init.io);
    }

    UnityMain(winapi.GetModuleHandleA(null).?, null, winapi.GetCommandLineW(), 1);

    return 0;
}

fn initPatches(base: usize) !void {
    LSplashScreenController.initFunctionPointers(base);
    AzurShell.initFunctionPointers(base);
    String.initFunctionPointers(base);
    Uri.initFunctionPointers(base);
    TableMgr.initFunctionPointers(base);

    try LSplashScreenController.initPatches();
    try AzurShell.initPatches();
    try Uri.initPatches();
    try TableMgr.initPatches();

    try interceptor.replace(base + 0x4370F20, enableSdkReplacement);
    try interceptor.replace(base + 0x436AAB0, enableSdkReplacement);
    try interceptor.write(base + 0x4059F36, &.{ 0xE9, 0xB7, 0x00 }); // No device requirements error
    try interceptor.replace(base + 0x4370CF0, getApiUrlReplacement);
    try interceptor.replace(base + 0x436AD60, getLogUrlReplacement);

    try interceptor.write(base + 0x1774410, &.{0xC3}); // CameraColliderMain::FadeByDistanceToCamera
    try interceptor.write(base + 0x1774F70, &.{0xC3}); // CameraColliderMain::FadeNpcByDistanceToCamera

    try interceptor.write(base + 0x28FA750, &.{ 0x31, 0xC0, 0xC3 }); // Compression
}

fn enableSdkReplacement(_: usize) callconv(.c) u8 {
    return 0;
}

fn getApiUrlReplacement() callconv(.c) *String {
    return .fromAnsi(config.cdnsv_url);
}

fn getLogUrlReplacement() callconv(.c) *String {
    return .fromAnsi(config.logsv_url);
}

const LSplashScreenController = opaque {
    const off_start = 0x40581D0;

    var startImpl: *const fn (*LSplashScreenController) callconv(.c) void = undefined;

    pub fn initFunctionPointers(base: usize) void {
        startImpl = @ptrFromInt(base + off_start);
    }

    pub fn initPatches() !void {
        try interceptor.replace(@intFromPtr(startImpl), startReplacement);
    }

    fn startReplacement(this: *LSplashScreenController) callconv(.c) void {
        @as(*[4]f32, @ptrFromInt(@intFromPtr(this) + 0x44)).* = @splat(-114514.0);
        @as(*f32, @ptrFromInt(@intFromPtr(this) + 0x54)).* = 0.5;
    }
};

const AzurShell = opaque {
    const off_start = 0x4356860;
    const off_launchoptionstart = 0x43560F0;

    var startImpl: *const fn (*AzurShell) callconv(.c) void = undefined;
    var launchOptionStartImpl: *const fn (*AzurShell) callconv(.c) void = undefined;

    pub fn initFunctionPointers(base: usize) void {
        startImpl = @ptrFromInt(base + off_start);
        launchOptionStartImpl = @ptrFromInt(base + off_launchoptionstart);
    }

    pub fn initPatches() !void {
        try interceptor.replaceRaw(@intFromPtr(startImpl), launchOptionStartImpl);
    }
};

const Uri = opaque {
    const off_ctor = 0x8C325C0;
    const off_createthis = 0x8C26D00;
    const https_prefix = "https://";

    const Kind = enum(i32) {
        relative_or_absolute = 0,
        absolute = 1,
        relative = 2,
    };

    var ctorImpl: *const fn (*Uri, *String) callconv(.c) void = undefined;
    var createThisImpl: *const fn (*Uri, *String, bool, Kind) callconv(.c) void = undefined;

    pub fn initFunctionPointers(base: usize) void {
        ctorImpl = @ptrFromInt(base + off_ctor);
        createThisImpl = @ptrFromInt(base + off_createthis);
    }

    pub fn initPatches() !void {
        if (config.log_http_requests) {
            try interceptor.replace(@intFromPtr(ctorImpl), ctorReplacement);
        }
    }

    fn ctorReplacement(this: *Uri, uri: *String) callconv(.c) void {
        const log = std.log.scoped(.http);

        log.info("Uri.ctor(\"{f}\")", .{unicode.fmtUtf16Le(uri.slice())});
        this.createThis(uri, false, .absolute);
    }

    pub fn createThis(this: *Uri, uri: *String, dont_escape: bool, kind: Kind) void {
        return createThisImpl(this, uri, dont_escape, kind);
    }
};

const TableMgr = opaque {
    const off_getLangValue = 0x28EB460;
    const off_internalGetLangValue = 0x28EE540;
    const off_type_info = 0xC406118;

    const words_group = unicode.utf8ToUtf16LeStringLiteral("words");
    const words_errorCode = unicode.utf8ToUtf16LeStringLiteral("errorCode");

    var getLangValueImpl: *const fn (*String, i64) callconv(.c) *String = undefined;
    var internalGetLangValueImpl: *const fn (*TableMgr, *String, i64) callconv(.c) *String = undefined;
    var type_info_ptr: *const usize = undefined;

    pub fn initFunctionPointers(base: usize) void {
        getLangValueImpl = @ptrFromInt(base + off_getLangValue);
        internalGetLangValueImpl = @ptrFromInt(base + off_internalGetLangValue);
        type_info_ptr = @ptrFromInt(base + off_type_info);
    }

    pub fn initPatches() !void {
        try interceptor.replace(@intFromPtr(getLangValueImpl), getLangValueReplacement);
    }

    fn getLangValueReplacement(group: *String, key: i64) callconv(.c) *String {
        const static_fields_ptr: **usize = @ptrFromInt(type_info_ptr.* + 0xB8);
        const maybe_instance: ?*TableMgr = @ptrFromInt(static_fields_ptr.*.*);
        const instance = maybe_instance orelse return .fromAnsi("");

        if (std.mem.eql(u16, group.slice(), words_group) and key == -8554740884682567094) {
            var d: [923]u16 = @splat(0);

            for ([_]u16{ 43306, 3729, 15760, 32048, 30784, 48525, 31587, 55075, 26212, 53516, 39832, 15937, 30900, 36029, 25467, 9975, 51079, 56280, 14262, 15730, 26182, 4309, 47497, 58259, 42892, 55499, 46647, 29295, 30844, 48525, 31587, 55075, 26212, 53517, 39832, 15929, 30952, 36029, 25467, 9975, 51079, 56280, 14262, 15730, 26182, 4325, 47497, 58243, 26510, 55499, 46647, 29295, 30844, 48525, 31587, 55075, 26212, 53520, 39832, 15928, 30914, 36029, 25467, 9975, 50183, 6351, 46647, 29295, 18042, 49360, 37409, 29555, 52519, 3023, 47025, 28524, 31972, 36081, 25467, 9975, 42087, 3277, 6434, 14135, 59004, 48368, 31515, 63174, 18382, 3848, 47025, 28524, 31460, 53388, 8634, 29475, 51142, 20251, 45463, 27759, 58590, 61688, 31515, 63174, 18350, 52488, 41500, 14131, 31852, 61828, 6523, 50934, 61005, 36623, 47025, 28524, 31460, 53388, 8730, 29491, 51142, 3865, 45463, 27759, 58590, 61688, 31515, 63174, 18350, 52488, 41506, 14131, 31850, 61844, 6523, 50934, 61005, 34831, 12702, 27759, 58590, 36084, 39337, 17475, 59046, 39055, 6046, 28515, 57048, 63944, 6627, 50934, 61005, 18639, 39578, 13380, 26734, 58617, 31201, 63030, 36333, 36764, 7696, 28515, 57048, 62920, 43289, 17300, 34534, 3981, 7721, 25391, 55518, 51645, 57841, 63030, 36333, 36700, 39569, 17475, 28264, 63692, 58153, 13046, 60813, 56475, 7711, 28515, 57048, 62920, 43289, 17492, 42726, 53132, 7739, 25391, 55518, 51645, 57841, 63030, 36333, 36700, 39697, 17456, 28266, 63692, 58153, 13046, 60813, 56475, 7711, 28515, 57048, 62920, 45337, 17204, 42726, 36748, 7737, 25391, 55518, 51645, 57841, 63030, 36333, 36700, 39697, 17461, 28266, 63688, 58265, 13046, 60813, 56475, 7711, 28515, 57048, 62920, 45337, 17268, 50918, 20364, 40498, 25391, 55518, 51645, 57841, 63030, 36333, 36700, 39697, 17465, 28268, 63684, 58145, 13046, 60813, 56475, 7711, 28515, 57048, 62920, 45337, 17460, 50918, 20364, 7721, 25391, 55518, 51645, 57841, 63030, 36333, 36700, 39697, 17477, 28268, 63680, 58233, 13046, 60813, 56475, 7711, 28515, 57048, 62920, 47385, 17156, 50918, 3980, 40503, 25391, 55518, 51645, 57841, 63030, 36333, 36700, 39825, 17459, 28270, 63680, 58217, 13046, 60813, 56475, 7711, 28515, 57048, 62920, 47385, 17236, 59078, 36753, 40505, 25391, 55518, 51645, 57841, 63030, 36333, 36700, 39825, 17463, 27758, 63768, 57713, 13046, 60813, 56475, 4127, 25404, 55518, 51645, 6633, 13172, 34568, 37197, 9503, 12092, 57030, 48561, 62353, 13254, 60813, 56475, 37278, 17719, 28808, 5337, 31219, 62402, 28140, 7131, 7993, 25404, 55518, 51645, 6633, 899, 34568, 37197, 13471, 12092, 57030, 48561, 62353, 13254, 60813, 56475, 37278, 13112, 28808, 4313, 29171, 62402, 28140, 7131, 7993, 15392, 57030, 48561, 60305, 33331, 59526, 19854, 7970, 15477, 50782, 45501, 37755, 50147, 28140, 7131, 7865, 14371, 34946, 55524, 61977, 50995, 60517, 56091, 47415, 8254, 50808, 45501, 37755, 13266, 2215, 3665, 8603, 28478, 24184, 48525, 31587, 59171, 35943, 56091, 47415, 9021, 24690, 1297, 4530, 58342, 34279, 56280, 14262, 15986, 30784, 48525, 31587, 55075, 26404, 20749, 39712, 15937, 30920, 36029, 25467, 9975, 51079, 56280, 14262, 15730, 29254, 4317, 45577, 58387, 10125, 55499, 46647, 29295, 30844, 48525, 31587, 55075, 26404, 20752, 39712, 15937, 30950, 36029, 25467, 9975, 51079, 56280, 14262, 15730, 29254, 4365, 45585, 58259, 26508, 55499, 46647, 29295, 30844, 48525, 31587, 55075, 26404, 20753, 6945, 15929, 30942, 36029, 25467, 9975, 51079, 56280, 14262, 15730, 33350, 4289, 45585, 58259, 18318, 55499, 46647, 29295, 30844, 48525, 31587, 55075, 26660, 53516, 6945, 15928, 30920, 36029, 25467, 9975, 50183, 6351, 46647, 29295, 18042, 56580, 6690, 33635, 52263, 3023, 47025, 28524, 31972, 36081, 25467, 9975, 42087, 20560, 8610, 14134, 59516, 48368, 31515, 63174, 18382, 3848, 47025, 28524, 31460, 1165, 8746, 25651, 59334, 3866, 45463, 27759, 58590, 61688, 31515, 63174, 18350, 53384, 8728, 13892, 31852, 61904, 6523, 50934, 61005, 36623, 47025, 28524, 31460, 2189, 8602, 25667, 51142, 3869, 45463, 27759, 58590, 61688, 31515, 63174, 18350, 53384, 41498, 13892, 31852, 61888, 6523, 50934, 61005, 36623, 47025, 28524, 31460, 2189, 8634, 25667, 42950, 53020, 45463, 27759, 58590, 61688, 31515, 63174, 18350, 53384, 41504, 13893, 31850, 61672, 6523, 50934, 61005, 36623, 47025, 28524, 31460, 2189, 8730, 25683, 42950, 53003, 45463, 27759, 58590, 61688, 31515, 63174, 18350, 53384, 41506, 13893, 31848, 61628, 6523, 50934, 61005, 36623, 47025, 28524, 31460, 3213, 8586, 25683, 34758, 3865, 45463, 27759, 58590, 61688, 31515, 63174, 18350, 53448, 41497, 13893, 31848, 61860, 6523, 50934, 61005, 36623, 47025, 28524, 31460, 3213, 8618, 25699, 26566, 53020, 45463, 27759, 58590, 61688, 31515, 63174, 18350, 53448, 41499, 13894, 31846, 61836, 6523, 50934, 61005, 36623, 47025, 28524, 31460, 3213, 8714, 25699, 18374, 53019, 45463, 27759, 58590, 61688, 31515, 63174, 18350, 53448, 41505, 13894, 31844, 61896, 6523, 50934, 61005, 36623, 47025, 28524, 31460, 3213, 10794, 25347, 18374, 3865, 45463, 27759, 58590, 61688, 31515, 63174, 18350, 53512, 41624, 13872, 31842, 61624, 6523, 50934, 61005, 36623, 47025, 28524, 31460, 4237, 10650, 25347, 10182, 53017, 45463, 27759, 58590, 61688, 31515, 63174, 18350, 53512, 41626, 13872, 31842, 61852, 6523, 50934, 61005, 36623, 47025, 28524, 31460, 4237, 10682, 25347, 1990, 53003, 45463, 27759, 58590, 61688, 31515, 63174, 18350, 53512, 41632, 13873, 31840, 61896, 6523, 50934, 61005, 36623, 47025, 28524, 31460, 4237, 10778, 25363, 1990, 20249, 45463, 27759, 58590, 61688, 31515, 63174, 18350, 53512, 41634, 13617, 31884, 61912, 6523, 50934, 61005, 36623, 47025, 28524, 31460, 5261, 10634, 21267, 51144, 20249, 45463, 27759, 58590, 61688, 31515, 63174, 18350, 53576, 41625, 13618, 31884, 61896, 6523, 50934, 61005, 36623, 47025, 28524, 31460, 5261, 10666, 21283, 42952, 53020, 45463, 27759, 58590, 61688, 31515, 63174, 18350, 53576, 41627, 13618, 31882, 61844, 6523, 50934, 61005, 36623, 47025, 28524, 31460, 5261, 10762, 21283, 42952, 3865, 45463, 27759, 58590, 61688, 31515, 63174, 18350, 53576, 41633, 13618, 31880, 61896, 6523, 50934, 61005, 36623, 47025, 28524, 31460, 5261, 10794, 21299, 34760, 53019, 45463, 27759, 58590, 61688, 31515, 63174, 18350, 53640, 41624, 13619, 31880, 61884, 6523, 50934, 61005, 36623, 47025, 28524, 31460, 6285, 10650, 21299, 26568, 20251, 45463, 27759, 58590, 61688, 31515, 63174, 18350, 53640, 41626, 13619, 31878, 61900, 6523, 50934, 61005, 34831 }, 0..d.len - 1) |v, i| {
                const b: i16 = @bitCast(@as(u16, @truncate(@subWithOverflow(((i + ((i >> 31) >> 29)) & 0xF8), i).@"0")));
                d[i] = @byteSwap(v >> @as(u4, @intCast(@mod(-11 - b, 16))) | v << @as(u4, @intCast(@mod(b + 11, 16))));
            }

            return .fromAnsi(@ptrCast(&d));
        }

        // Ban message
        if (std.mem.eql(u16, group.slice(), words_errorCode) and key == 42988327666176) {
            return .fromAnsi("{2}");
        }

        return internalGetLangValueImpl(instance, group, key);
    }
};

const String = opaque {
    const off_stringToHGlobalAnsi = 0x81446B0;
    const off_ptrToStringAnsi = 0x8142690;

    var stringToHGlobalAnsiImpl: *const fn (*String) callconv(.c) [*:0]const u8 = undefined;
    var ptrToStringAnsiImpl: *const fn ([*:0]const u8) callconv(.c) *String = undefined;

    pub fn initFunctionPointers(base: usize) void {
        stringToHGlobalAnsiImpl = @ptrFromInt(base + off_stringToHGlobalAnsi);
        ptrToStringAnsiImpl = @ptrFromInt(base + off_ptrToStringAnsi);
    }

    pub fn toAnsi(s: *String) [*:0]const u8 {
        return stringToHGlobalAnsiImpl(s);
    }

    pub fn fromAnsi(cstr: [*:0]const u8) *String {
        return ptrToStringAnsiImpl(cstr);
    }

    pub fn slice(s: *String) []const u16 {
        const len: *u32 = @ptrFromInt(@intFromPtr(s) + 16);
        const ptr: [*]const u16 = @ptrFromInt(@intFromPtr(s) + 20);
        return ptr[0..len.*];
    }
};

fn loadLibrary(name: [:0]const u8) *winapi.HMODULE {
    return winapi.LoadLibraryA(name) orelse
        fatal("{s} is missing, make sure you've put this exe into the game directory", .{name});
}

fn printDoro(io: std.Io) void {
    const stderr = std.Io.File.stderr();
    stderr.writeStreamingAll(
        io,
        if (stderr.enableAnsiEscapeCodes(io))
            "\x1b[95mDoro-colorFUL\x1b[0m\n" // colorful
        else |_|
            "Doro-colorLESS\n", // colorless / fallback
    ) catch {};
}

const Config = struct {
    cdnsv_url: [:0]const u8,
    logsv_url: [:0]const u8,
    log_http_requests: bool,
};

const fatal = process.fatal;
const process = std.process;
const unicode = std.unicode;

const config: Config = @import("config.zon");

const interceptor = @import("interceptor.zig");
const winapi = @import("winapi.zig");
const debug = @import("debug.zig");
const std = @import("std");
