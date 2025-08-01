const std = @import("std");
const build_options = @import("build_options");
const builtin = @import("builtin");
const is_windows = builtin.os.tag == .windows;
const SCRIPT_PATH = "run.bat";
const TIMEPATH = "docs/time.json";

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{ .safety = true }){};
    const allocator = gpa.allocator();
    var buf: [32]u8 = undefined;
    while (true) {
        waitForChangeBlocking("src");
        std.debug.print("recompiling...\t\t", .{});
        const command: []const []const u8 = if (is_windows) &[1][]const u8{SCRIPT_PATH} else &[2][]const u8{ "bash", SCRIPT_PATH };
        var process = std.process.Child.init(command, allocator);
        process.cwd_dir = std.fs.cwd();
        _ = try process.spawnAndWait();
        const time = std.fmt.bufPrint(&buf, "{d}", .{std.time.milliTimestamp()}) catch unreachable;
        const file = try std.fs.cwd().createFile(TIMEPATH, .{});
        defer file.close();
        _ = try file.writeAll(time);
    }
}

/// Uses the system apis to create a blocking call that only returns
/// when there has been some change in the dir at path
fn waitForChangeBlocking(path: []const u8) void {
    if (is_windows) {
        var dirname_path_space: std.os.windows.PathSpace = undefined;
        dirname_path_space.len = std.unicode.utf8ToUtf16Le(&dirname_path_space.data, path) catch unreachable;
        dirname_path_space.data[dirname_path_space.len] = 0;
        const dir_handle = std.os.windows.OpenFile(dirname_path_space.span(), .{
            .dir = std.fs.cwd().fd,
            .access_mask = std.os.windows.GENERIC_READ,
            .creation = std.os.windows.FILE_OPEN,
            //.io_mode = .blocking,
            .filter = .dir_only,
            .follow_symlinks = false,
        }) catch |err| {
            std.debug.print("Error in opening file: {any}\n", .{err});
            unreachable;
        };
        var event_buf: [4096]u8 align(@alignOf(std.os.windows.FILE_NOTIFY_INFORMATION)) = undefined;
        var num_bytes: u32 = 0;
        // The ReadDirectoryChangesW is synchronous. So the thread will wait for the completion of
        // this line until there has been a change before continuing (which in this case is to return).
        _ = std.os.windows.kernel32.ReadDirectoryChangesW(
            dir_handle,
            &event_buf,
            event_buf.len,
            std.os.windows.FALSE, // watch subtree
            .{ .last_write = true },
            // std.os.windows.FILE_NOTIFY_CHANGE_FILE_NAME | std.os.windows.FILE_NOTIFY_CHANGE_DIR_NAME |
            //     std.os.windows.FILE_NOTIFY_CHANGE_ATTRIBUTES | std.os.windows.FILE_NOTIFY_CHANGE_SIZE |
            //     std.os.windows.FILE_NOTIFY_CHANGE_LAST_WRITE | std.os.windows.FILE_NOTIFY_CHANGE_LAST_ACCESS |
            //     std.os.windows.FILE_NOTIFY_CHANGE_CREATION | std.os.windows.FILE_NOTIFY_CHANGE_SECURITY,
            &num_bytes, // number of bytes transferred (unused for async)
            null,
            null, // completion routine - unused because we use IOCP
        );
    } else {
        // kevent stuff. Only tested on my mac
        const flags = std.posix.O.SYMLINK | std.posix.O.EVTONLY;
        const fd = std.os.open(path, flags, 0) catch unreachable;
        // create kqueue and kevent
        const kq = std.os.kqueue() catch unreachable;
        var kevs = [1]std.os.Kevent{undefined};
        kevs[0] = std.os.Kevent{
            .ident = @as(usize, @intCast(fd)),
            .filter = std.c.EVFILT_VNODE,
            .flags = std.c.EV_ADD | std.c.EV_ENABLE | std.c.EV_ONESHOT,
            .fflags = std.c.NOTE_WRITE,
            .data = 0,
            .udata = undefined,
        };
        var kev_response = [1]std.os.Kevent{undefined};
        const empty_kevs = &[0]std.os.Kevent{};
        // add kevent to kqueue
        _ = std.os.kevent(kq, &kevs, empty_kevs, null) catch unreachable;
        // wait for kqueue to send back message.
        _ = std.os.kevent(kq, empty_kevs, &kev_response, null) catch unreachable;
        // TODO (19 Oct 2023 sam): How to close kqueue?
    }
}
