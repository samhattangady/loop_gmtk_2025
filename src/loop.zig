const std = @import("std");
const c = @import("interface.zig");
const haathi_lib = @import("haathi.zig");
const Haathi = @import("haathi.zig").Haathi;
const colors = @import("colors.zig");
const MouseState = @import("inputs.zig").MouseState;
const SCREEN_SIZE = @import("haathi.zig").SCREEN_SIZE;
const CursorStyle = @import("haathi.zig").CursorStyle;
const serializer = @import("serializer.zig");

const helpers = @import("helpers.zig");
const Vec2 = helpers.Vec2;
const Vec2i = helpers.Vec2i;
const Vec4 = helpers.Vec4;
const Rect = helpers.Rect;
const Button = helpers.Button;
const TextLine = helpers.TextLine;
const Orientation = helpers.Orientation;
const ConstIndexArray = helpers.ConstIndexArray;
const ConstKey = helpers.ConstKey;
const FONTS = haathi_lib.FONTS;

const build_options = @import("build_options");
const BUILDER_MODE = build_options.builder_mode;
const WORLD_SIZE = SCREEN_SIZE;
const WORLD_OFFSET = Vec2{};

// World has origin at the center, x-right, y-up.
// Screen has origin at bottomleft, x-right, y-up
const World = struct {
    size: Vec2 = WORLD_SIZE,
    offset: Vec2 = WORLD_OFFSET,
    center: Vec2 = WORLD_OFFSET.add(WORLD_SIZE.scale(0.5)),

    pub fn init(allocator: std.mem.Allocator) World {
        _ = allocator;
        return .{};
    }

    pub fn setup(self: *World) void {
        _ = self;
    }

    pub fn deinit(self: *World) void {
        _ = self;
    }

    pub fn clear(self: *World) void {
        _ = self;
    }

    pub fn worldToScreen(self: *const World, position: Vec2) Vec2 {
        return position.add(self.center);
    }

    pub fn screenToWorld(self: *const World, position: Vec2) Vec2 {
        return position.subtract(self.center);
    }
};

// gameStruct
pub const Game = struct {
    haathi: *Haathi,
    ticks: u32 = 0,
    steps: u32 = 0,
    world: World,
    ff_mode: bool = false,

    xosh: std.Random.Xoshiro256,
    rng: std.Random = undefined,
    allocator: std.mem.Allocator,
    arena_handle: std.heap.ArenaAllocator,
    arena: std.mem.Allocator,

    pub const serialize_fields = [_][]const u8{
        "ticks",
        "steps",
        "world",
    };

    pub fn init(haathi: *Haathi) Game {
        // haathi.loadSound("audio/click_down_3.mp3", false);
        // for (ALL_SPRITES) |path| haathi.loadSpriteMap(path);
        const allocator = haathi.allocator;
        var arena_handle = std.heap.ArenaAllocator.init(std.heap.page_allocator);
        const world = World.init(haathi.allocator);
        return .{
            .haathi = haathi,
            .xosh = std.Random.Xoshiro256.init(0),
            .world = world,
            .allocator = allocator,
            .arena_handle = arena_handle,
            .arena = arena_handle.allocator(),
        };
    }

    pub fn deinit(self: *Game) void {
        self.world.deinit();
    }

    fn clear(self: *Game) void {
        self.world.clear();
    }

    fn reset(self: *Game) void {
        self.clear();
        self.setup();
    }

    pub fn setup(self: *Game) void {
        self.rng = self.xosh.random();
    }

    pub fn saveGame(self: *Game) void {
        var stream = serializer.JsonStream.new(self.haathi.arena);
        var js = stream.serializer();
        js.beginObject() catch unreachable;
        serializer.serialize("game", self.*, &js) catch unreachable;
        js.endObject() catch unreachable;
        stream.webSave("save") catch unreachable;
    }

    pub fn loadGame(self: *Game) void {
        if (helpers.webLoad("save", self.haathi.arena)) |savefile| {
            const tree = std.json.parseFromSlice(std.json.Value, self.haathi.arena, savefile, .{}) catch |err| {
                helpers.debugPrint("parsing error {}\n", .{err});
                unreachable;
            };
            //self.sim.clearSim();
            serializer.deserialize("game", self, tree.value, .{ .allocator = self.haathi.allocator, .arena = self.haathi.arena });
            // self.resetMenu();
            // self.setupContextual();
        } else {
            helpers.debugPrint("no savefile found", .{});
        }
    }

    // updateGame
    pub fn update(self: *Game, ticks: u64) void {
        // clear the arena and reset.
        self.steps += 1;
        _ = self.arena_handle.reset(.retain_capacity);
        self.arena = self.arena_handle.allocator();
        self.ticks = @intCast(ticks);
    }

    pub fn render(self: *Game) void {
        // background
        // self.haathi.drawSprite(.{
        //     .sprite = .{
        //         .path = "img/bg.png",
        //         .anchor = .{},
        //         .size = SCREEN_SIZE,
        //     },
        //     .position = .{},
        // });
        self.haathi.drawRect(.{
            .position = .{},
            .size = WORLD_SIZE,
            .color = .{ .x = 1, .y = 1, .z = 0, .w = 1 },
        });
    }
};
