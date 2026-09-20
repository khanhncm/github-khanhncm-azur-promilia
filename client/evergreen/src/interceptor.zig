pub const ReplaceError = std.process.ProtectMemoryError;

pub fn replace(address: usize, comptime function: anytype) ReplaceError!void {
    return replaceRaw(address, &function);
}

pub fn replaceRaw(address: usize, replacement: *const anyopaque) ReplaceError!void {
    const trampoline_size: usize = 12;
    const alignment = std.heap.page_size_min;

    const start = std.mem.alignBackward(usize, address, alignment);
    const end = std.mem.alignForward(usize, address + trampoline_size, alignment);
    const pages = @as([*]align(alignment) u8, @ptrFromInt(start))[0 .. end - start];

    try std.process.protectMemory(
        pages,
        .{ .read = true, .write = true, .execute = true },
    );

    const location: [*]u8 = @ptrFromInt(address);
    var writer: Io.Writer = .fixed(location[0..12]);
    writer.writeAll(&.{ 0x48, 0xB8 }) catch unreachable; // mov ${}, %rax
    writer.writeInt(u64, @intFromPtr(replacement), .little) catch unreachable; // ${}
    writer.writeAll(&.{ 0x50, 0xC3 }) catch unreachable; // push %rax; ret

    std.process.protectMemory(
        pages,
        .{ .read = true, .write = false, .execute = true },
    ) catch return; // Reprotect should not fail. Well, even if it does, we don't really care.
}

pub fn write(address: usize, bytes: []const u8) ReplaceError!void {
    const alignment = std.heap.page_size_min;

    const start = std.mem.alignBackward(usize, address, alignment);
    const end = std.mem.alignForward(usize, address + bytes.len, alignment);
    const pages = @as([*]align(alignment) u8, @ptrFromInt(start))[0 .. end - start];

    try std.process.protectMemory(
        pages,
        .{ .read = true, .write = true, .execute = true },
    );

    const location: [*]u8 = @ptrFromInt(address);
    var writer: Io.Writer = .fixed(location[0..bytes.len]);
    writer.writeAll(bytes) catch unreachable; // mov ${}, %rax

    std.process.protectMemory(
        pages,
        .{ .read = true, .write = false, .execute = true },
    ) catch return; // Reprotect should not fail. Well, even if it does, we don't really care.
}

const Io = std.Io;
const std = @import("std");
