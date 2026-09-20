pub const PROC = opaque {};
pub const HANDLE = windows.HANDLE;
pub const LPWSTR = windows.LPWSTR;
pub const HMODULE = windows.HMODULE;

pub extern "kernel32" fn GetModuleHandleA(name: ?[*:0]const u8) callconv(.winapi) ?*HMODULE;
pub extern "kernel32" fn LoadLibraryA(lib_file_name: [*:0]const u8) callconv(.winapi) ?*HMODULE;

pub extern "kernel32" fn GetProcAddress(
    module: *HMODULE,
    proc_name: [*:0]const u8,
) callconv(.winapi) ?*PROC;

pub extern "kernel32" fn GetCommandLineW() callconv(.winapi) LPWSTR;

pub extern "kernel32" fn FreeConsole() callconv(.winapi) void;
pub extern "kernel32" fn AllocConsole() callconv(.winapi) void;

pub extern "kernel32" fn Sleep(dw_milliseconds: u32) callconv(.winapi) void;

const windows = @import("std").os.windows;
