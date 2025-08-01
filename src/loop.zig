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
const asf32 = helpers.asf32;
const FONTS = haathi_lib.FONTS;
const Sprite = haathi_lib.Sprite;

const build_options = @import("build_options");
const BUILDER_MODE = build_options.builder_mode;
const WORLD_SIZE = SCREEN_SIZE;
const WORLD_X = WORLD_SIZE.x;
const WORLD_Y = WORLD_SIZE.y;
const WORLD_OFFSET = Vec2{};
const WORLD_CENTER = WORLD_SIZE.scale(0.5);
const HOVER_DIST = 8;
const HOVER_DIST_SQR = HOVER_DIST * HOVER_DIST;

const ALL_SPRITES = [_][]const u8{
    "img/kenney_cursors/hand_thin_open.png",
    "img/kenney_cursors/hand_thin_point.png",
    "img/kenney_cursors/hand_thin_closed.png",
    "img/kenney_cursors/cursor_none.png",
    "img/broom_walk_base.png",
    "img/broom_walk_water.png",
    "img/broom_walk_carry.png",
    "img/wheat.png",
    "img/flour.png",
    "img/bread.png",
    "img/gold.png",
};

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

pub const Point = struct {
    position: Vec2,
};

pub const Mover = struct {
    const SPRITE_COUNT = 4;
    const SPRITE_WIDTH = 64;
    const SPRITE_HEIGHT = 64;

    position: Vec2,
    prev_position: Vec2 = .{},
    fraction: f32,
    carrying: ?Material = null,
    sprite_index: u8 = 0,
    anim_tick: f32 = 0,

    pub fn getBaseSprite(self: *const Mover) Sprite {
        return .{
            .path = "img/broom_walk_base.png",
            .size = .{ .x = SPRITE_WIDTH, .y = SPRITE_HEIGHT },
            .anchor = .{ .x = SPRITE_WIDTH * asf32(self.sprite_index), .y = 0 },
        };
    }

    pub fn getCarryingSprite(self: *const Mover, material: Material) Sprite {
        const path = switch (material) {
            .water => "img/broom_walk_water.png",
            .flour,
            .wheat,
            .bread,
            .gold,
            => "img/broom_walk_carry.png",
        };
        return .{
            .path = path,
            .size = .{ .x = SPRITE_WIDTH, .y = SPRITE_HEIGHT },
            .anchor = .{ .x = SPRITE_WIDTH * asf32(self.sprite_index), .y = 0 },
        };
    }

    pub fn getExtraSprite(self: *const Mover, material: Material) struct { ?Sprite, Vec2 } {
        if (material == .water) return .{ null, .{} };
        const path = switch (material) {
            .water => "img/wheat.png",
            .wheat => "img/wheat.png",
            .flour => "img/flour.png",
            .bread => "img/bread.png",
            .gold => "img/gold.png",
        };
        const offsets = [SPRITE_COUNT]Vec2{
            .{ .x = 0, .y = 55 },
            .{ .x = 3, .y = 57 },
            .{ .x = 5, .y = 55 },
            .{ .x = 0, .y = 50 },
        };
        return .{ .{
            .path = path,
            .size = .{ .x = SPRITE_WIDTH, .y = SPRITE_HEIGHT * 0.25 },
            .anchor = .{ .x = 0, .y = 0 },
        }, offsets[self.sprite_index] };
    }
};

pub const Material = enum {
    water,
    wheat,
    flour,
    bread,
    gold,

    pub fn score(self: *const Material) u32 {
        return std.math.pow(u32, 2, @intFromEnum(self.*));
    }
};

pub const Zone = struct {
    name: []const u8,
    rect: Rect,
    is_consumer: bool,
    material: Material,
    count: u32 = 0,
    available: u32 = 0,
    error_count: u32 = 0,
    show_count: bool = false,
    linked: ?usize = null,
    hidden: bool = true,

    fn deliver(self: *Zone, mat: Material, game: *Game) bool {
        if (self.hidden) return false;
        if (mat == self.material) {
            self.count += 1;
            if (self.linked) |next| {
                const other = &game.zones.items[next];
                other.available += 1;
            }
            return true;
        } else {
            self.error_count += 1;
            return false;
        }
    }

    fn pickup(self: *Zone, game: *Game) ?Material {
        if (self.hidden) return null;
        if (self.available > 0) {
            self.count += 1;
            self.available -= 1;
            return self.material;
        }
        // TODO (01 Aug 2025 sam): tell game that this was empty
        _ = game;
        return null;
    }
};

pub const Quest = struct {
    text: []const u8,
    reqd: u32 = 0,
    zone_count_index: u32 = 0,
    shown: bool = false,
    completed: bool = false,
    claimed: bool = false,
    position: Vec2 = .{},
    zones_unlocked: []const u8 = &.{},
    quests_unlocked: []const u8 = &.{},
    actions: []const u8 = &.{},
    button: Button,
};

pub const ButtonAction = enum {
    loop_size_increase,
    worker_add,
    worker_speed_increase,
    quest_complete,
};

// gameStruct
pub const Game = struct {
    haathi: *Haathi,
    ticks: u32 = 0,
    steps: u32 = 0,
    score: u32 = 0,
    world: World,
    ff_mode: bool = false,
    points: std.ArrayList(Point),
    movers: std.ArrayList(Mover),
    buttons: std.ArrayList(Button),
    zones: std.ArrayList(Zone),
    quests: std.ArrayList(Quest),
    hovered_point: ?usize = null,
    point_spacing: f32 = 0,
    hovered_offset: Vec2 = .{},
    hovered_position: Vec2 = .{},
    move_fraction: f32 = 1,
    anim_progress: f32 = 1.0 / 7.0,

    xosh: std.Random.Xoshiro256,
    rng: std.Random = undefined,
    allocator: std.mem.Allocator,
    arena_handle: std.heap.ArenaAllocator,
    arena: std.mem.Allocator,

    const POINT_COUNT_START = 16;
    const MOVER_COUNT_START = 4;
    const MAJOR_AXIS = 100;

    pub const serialize_fields = [_][]const u8{
        "ticks",
        "steps",
        "world",
    };

    pub fn init(haathi: *Haathi) Game {
        // haathi.loadSound("audio/click_down_3.mp3", false);
        haathi.setCursor(.none);
        for (ALL_SPRITES) |path| haathi.loadSpriteMap(path);
        const allocator = haathi.allocator;
        var arena_handle = std.heap.ArenaAllocator.init(std.heap.page_allocator);
        const world = World.init(haathi.allocator);
        var self = Game{
            .haathi = haathi,
            .xosh = std.Random.Xoshiro256.init(0),
            .zones = .init(haathi.allocator),
            .points = .init(haathi.allocator),
            .quests = .init(haathi.allocator),
            .movers = .init(haathi.allocator),
            .buttons = .init(haathi.allocator),
            .world = world,
            .allocator = allocator,
            .arena_handle = arena_handle,
            .arena = arena_handle.allocator(),
        };
        self.setup();
        return self;
    }

    pub fn deinit(self: *Game) void {
        self.world.deinit();
        self.zones.deinit();
        self.buttons.deinit();
        self.points.deinit();
        self.movers.deinit();
        self.quests.deinit();
    }

    fn clear(self: *Game) void {
        self.world.clear();
        self.zones.clearRetainingCapacity();
        self.buttons.clearRetainingCapacity();
        self.points.clearRetainingCapacity();
        self.movers.clearRetainingCapacity();
        self.quests.clearRetainingCapacity();
        self.move_fraction = 0.003;
        self.anim_progress = 1.0 / 7.0;
        self.score = 0;
    }

    fn reset(self: *Game) void {
        self.clear();
        self.setup();
    }

    pub fn setup(self: *Game) void {
        self.clear();
        self.rng = self.xosh.random();
        for (0..POINT_COUNT_START) |i| {
            const angle = helpers.fraction(i, POINT_COUNT_START) * std.math.pi * 2;
            self.points.append(.{ .position = WORLD_CENTER.add(.{ .x = @cos(angle) * MAJOR_AXIS, .y = @sin(angle) * MAJOR_AXIS }) }) catch unreachable;
        }
        self.point_spacing = self.points.items[0].position.distance(self.points.items[1].position);
        // self.hovered_point = 0;
        // self.runFabrik();
        // self.hovered_point = self.points.items.len / 2;
        // self.runFabrik();
        self.hovered_point = null;
        for (0..MOVER_COUNT_START) |i| {
            const fract = helpers.fraction(i, MOVER_COUNT_START);
            const pos = self.getPos(fract);
            self.movers.append(.{ .position = pos, .fraction = fract }) catch unreachable;
        }
        const ZONE_HEIGHT = 120;
        const ZONE_WIDTH = 180;
        self.zones.append(.{
            .name = "well",
            .rect = .{
                .position = .{ .x = 50, .y = 50 },
                .size = .{ .x = ZONE_WIDTH, .y = ZONE_HEIGHT },
            },
            .hidden = false,
            .available = std.math.maxInt(u32),
            .is_consumer = false,
            .material = .water,
        }) catch unreachable;
        self.zones.append(.{
            .name = "field",
            .rect = .{
                .position = .{ .x = 50, .y = WORLD_SIZE.y - ZONE_HEIGHT - 50 },
                .size = .{ .x = ZONE_WIDTH, .y = ZONE_HEIGHT },
            },
            .hidden = false,
            .is_consumer = true,
            .linked = 2,
            .material = .water,
        }) catch unreachable;
        self.zones.append(.{
            .name = "field",
            .rect = .{
                .position = .{ .x = 250, .y = WORLD_SIZE.y - ZONE_HEIGHT - 50 },
                .size = .{ .x = ZONE_WIDTH, .y = ZONE_HEIGHT },
            },
            .is_consumer = false,
            .material = .wheat,
        }) catch unreachable;
        self.zones.append(.{
            .name = "mill",
            .rect = .{
                .position = .{ .x = 600, .y = WORLD_SIZE.y - ZONE_HEIGHT - 50 },
                .size = .{ .x = ZONE_WIDTH, .y = ZONE_HEIGHT },
            },
            .is_consumer = true,
            .linked = 4,
            .material = .wheat,
        }) catch unreachable;
        self.zones.append(.{
            .name = "mill",
            .rect = .{
                .position = .{ .x = 800, .y = WORLD_SIZE.y - ZONE_HEIGHT - 50 - (ZONE_HEIGHT * 1.2) },
                .size = .{ .x = ZONE_WIDTH, .y = ZONE_HEIGHT },
            },
            .is_consumer = false,
            .material = .flour,
        }) catch unreachable;
        self.zones.append(.{
            .name = "bakery",
            .rect = .{
                .position = .{ .x = 800, .y = WORLD_SIZE.y - ZONE_HEIGHT - 50 - (ZONE_HEIGHT * 2.4) },
                .size = .{ .x = ZONE_WIDTH, .y = ZONE_HEIGHT },
            },
            .is_consumer = true,
            .linked = 6,
            .material = .flour,
        }) catch unreachable;
        self.zones.append(.{
            .name = "bakery",
            .rect = .{
                .position = .{ .x = 500, .y = WORLD_SIZE.y - ZONE_HEIGHT - 50 - (ZONE_HEIGHT * 2.4) },
                .size = .{ .x = ZONE_WIDTH, .y = ZONE_HEIGHT },
            },
            .is_consumer = false,
            .material = .bread,
        }) catch unreachable;
        self.zones.append(.{
            .name = "market",
            .rect = .{
                .position = .{ .x = 600, .y = WORLD_SIZE.y - ZONE_HEIGHT - 50 - (ZONE_HEIGHT * 4.2) },
                .size = .{ .x = ZONE_WIDTH, .y = ZONE_HEIGHT },
            },
            .is_consumer = true,
            .linked = 8,
            .material = .bread,
        }) catch unreachable;
        self.zones.append(.{
            .name = "market",
            .rect = .{
                .position = .{ .x = 400, .y = WORLD_SIZE.y - ZONE_HEIGHT - 50 - (ZONE_HEIGHT * 4.2) },
                .size = .{ .x = ZONE_WIDTH, .y = ZONE_HEIGHT },
            },
            .is_consumer = false,
            .material = .gold,
        }) catch unreachable;
        self.zones.append(.{
            .name = "vault",
            .rect = .{
                .position = .{ .x = 200 + (ZONE_WIDTH / 2), .y = WORLD_SIZE.y - ZONE_HEIGHT - 50 - (ZONE_HEIGHT * 2.6) },
                .size = .{ .x = ZONE_WIDTH / 2, .y = ZONE_HEIGHT },
            },
            .is_consumer = true,
            .show_count = true,
            .material = .gold,
        }) catch unreachable;
        self.buttons.append(.{
            .rect = .{
                .position = .{ .x = WORLD_X - 250, .y = 20 },
                .size = .{ .x = 200, .y = 36 },
            },
            .value = @intFromEnum(ButtonAction.loop_size_increase),
            .text = @tagName(ButtonAction.loop_size_increase),
        }) catch unreachable;
        self.buttons.append(.{
            .rect = .{
                .position = .{ .x = WORLD_X - 250, .y = 60 },
                .size = .{ .x = 200, .y = 36 },
            },
            .value = @intFromEnum(ButtonAction.worker_add),
            .text = @tagName(ButtonAction.worker_add),
        }) catch unreachable;
        self.buttons.append(.{
            .rect = .{
                .position = .{ .x = WORLD_X - 250, .y = 100 },
                .size = .{ .x = 200, .y = 36 },
            },
            .value = @intFromEnum(ButtonAction.worker_speed_increase),
            .text = @tagName(ButtonAction.worker_speed_increase),
        }) catch unreachable;
        //
        // quests_init
        //
        const task_list_y = 550;
        self.quests.append(.{
            .text = "water the crops",
            .reqd = 12,
            .zone_count_index = 1,
            .shown = true,
            .zones_unlocked = &.{ 2, 3 },
            .quests_unlocked = &.{1},
            .actions = &.{ 1, 0, 2 },
            .position = .{ .x = 1000, .y = task_list_y - (40 * asf32(self.quests.items.len)) },
            .button = .{
                .rect = .{ .position = .{ .x = 1100, .y = task_list_y - 25 - (40 * asf32(self.quests.items.len)) }, .size = .{ .x = 100, .y = 24 } },
                .value = @intFromEnum(ButtonAction.quest_complete),
                .text = "complete",
                .index = self.quests.items.len,
                .enabled = false,
            },
        }) catch unreachable;
        self.quests.append(.{
            .text = "transfer wheat to mill",
            .reqd = 20,
            .zone_count_index = 3,
            .actions = &.{ 0, 2 },
            .zones_unlocked = &.{ 4, 5 },
            .quests_unlocked = &.{2},
            .position = .{ .x = 1000, .y = task_list_y - (40 * asf32(self.quests.items.len)) },
            .button = .{
                .rect = .{ .position = .{ .x = 1100, .y = task_list_y - 25 - (40 * asf32(self.quests.items.len)) }, .size = .{ .x = 100, .y = 24 } },
                .value = @intFromEnum(ButtonAction.quest_complete),
                .text = "complete",
                .index = self.quests.items.len,
                .enabled = false,
            },
        }) catch unreachable;
        self.quests.append(.{
            .text = "deliver flour to bakery",
            .reqd = 24,
            .zone_count_index = 5,
            .actions = &.{ 1, 0 },
            .zones_unlocked = &.{ 6, 7 },
            .quests_unlocked = &.{3},
            .position = .{ .x = 1000, .y = task_list_y - (40 * asf32(self.quests.items.len)) },
            .button = .{
                .rect = .{ .position = .{ .x = 1100, .y = task_list_y - 25 - (40 * asf32(self.quests.items.len)) }, .size = .{ .x = 100, .y = 24 } },
                .value = @intFromEnum(ButtonAction.quest_complete),
                .text = "complete",
                .index = self.quests.items.len,
                .enabled = false,
            },
        }) catch unreachable;
        self.quests.append(.{
            .text = "sell bread in market",
            .reqd = 36,
            .zone_count_index = 7,
            .zones_unlocked = &.{ 8, 9 },
            .quests_unlocked = &.{4},
            .actions = &.{ 0, 1, 2 },
            .position = .{ .x = 1000, .y = task_list_y - (40 * asf32(self.quests.items.len)) },
            .button = .{
                .rect = .{ .position = .{ .x = 1100, .y = task_list_y - 25 - (40 * asf32(self.quests.items.len)) }, .size = .{ .x = 100, .y = 24 } },
                .value = @intFromEnum(ButtonAction.quest_complete),
                .text = "complete",
                .index = self.quests.items.len,
                .enabled = false,
            },
        }) catch unreachable;
        self.quests.append(.{
            .text = "store gold in vault",
            .reqd = 500,
            .zone_count_index = 9,
            .zones_unlocked = &.{},
            .quests_unlocked = &.{},
            .actions = &.{ 1, 2, 0 },
            .position = .{ .x = 1000, .y = task_list_y - (40 * asf32(self.quests.items.len)) },
            .button = .{
                .rect = .{ .position = .{ .x = 1100, .y = task_list_y - 25 - (40 * asf32(self.quests.items.len)) }, .size = .{ .x = 100, .y = 24 } },
                .value = @intFromEnum(ButtonAction.quest_complete),
                .text = "complete",
                .index = self.quests.items.len,
                .enabled = false,
            },
        }) catch unreachable;
    }

    pub fn getPos(self: *const Game, f: f32) Vec2 {
        const indexf = @divFloor(f * @as(f32, @floatFromInt(self.points.items.len)), 1.0);
        const index: usize = @intFromFloat(indexf);
        const start = self.points.items[self.pointIndex(index)].position;
        const end = self.points.items[self.pointIndex(index + 1)].position;
        const unlerp_start = indexf / @as(f32, @floatFromInt(self.points.items.len));
        const unlerp_end = (indexf + 1) / @as(f32, @floatFromInt(self.points.items.len));
        const progress = helpers.unlerp(unlerp_start, unlerp_end, f);
        return start.lerp(end, progress);
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

    pub fn pointIndex(self: *const Game, index: usize) usize {
        return index % self.points.items.len;
    }

    pub fn inZone(self: *const Game, position: Vec2) ?usize {
        for (self.zones.items, 0..) |zone, i| {
            if (zone.hidden) continue;
            if (zone.rect.contains(position)) return i;
        }
        return null;
    }

    pub fn runFabrikIteration(self: *Game, pt_index: usize, final_iteration: bool) void {
        const opposite_index = (pt_index + (self.points.items.len / 2)) % self.points.items.len;
        var start_pos = self.points.items[pt_index].position;
        var final_pos = self.points.items[opposite_index].position;
        _ = &start_pos;
        _ = &final_pos;
        var final: [2]Vec2 = undefined;
        for (0..self.points.items.len / 2) |i| {
            const p0 = self.points.items[self.pointIndex(pt_index + i)];
            const p1 = &self.points.items[self.pointIndex(pt_index + i + 1)];
            const distance = p0.position.distance(p1.position);
            const difference = p1.position.subtract(p0.position);
            p1.position = p0.position.add(difference.scale(self.point_spacing / distance));
        }
        final[0] = self.points.items[opposite_index].position;
        for (0..self.points.items.len / 2) |i| {
            const p0 = self.points.items[self.pointIndex(pt_index + self.points.items.len - i)];
            const p1 = &self.points.items[self.pointIndex(pt_index + self.points.items.len - i - 1)];
            const distance = p0.position.distance(p1.position);
            const difference = p1.position.subtract(p0.position);
            p1.position = p0.position.add(difference.scale(self.point_spacing / distance));
        }
        final[1] = self.points.items[opposite_index].position;
        self.points.items[opposite_index].position = final[0].lerp(final[1], 0.5);
        if (!final_iteration) {
            const angle_force: f32 = 1.5;
            for (0..6) |i| {
                {
                    const p0 = &self.points.items[self.pointIndex(pt_index + i + 1)];
                    const p1 = &self.points.items[self.pointIndex(pt_index + self.points.items.len + i - 1)];
                    const distance = p0.position.distance(p1.position);
                    if (distance < self.point_spacing * angle_force) {
                        const center = p0.position.lerp(p1.position, 0.5);
                        const difference = p1.position.subtract(center);
                        p1.position = center.add(difference.normalize().scale(self.point_spacing * angle_force / 2));
                        p0.position = center.add(difference.normalize().scale(-self.point_spacing * angle_force / 2));
                    }
                }
                {
                    const p0 = &self.points.items[self.pointIndex(pt_index + self.points.items.len - i + 1)];
                    const p1 = &self.points.items[self.pointIndex(pt_index + self.points.items.len - i - 1)];
                    const distance = p0.position.distance(p1.position);
                    if (distance < self.point_spacing * angle_force) {
                        const center = p0.position.lerp(p1.position, 0.5);
                        const difference = p1.position.subtract(center);
                        p1.position = center.add(difference.normalize().scale(self.point_spacing * angle_force / 2));
                        p0.position = center.add(difference.normalize().scale(-self.point_spacing * angle_force / 2));
                    }
                }
            }
            const point_force: f32 = 1;
            for (0..self.points.items.len) |i| {
                const p0 = &self.points.items[self.pointIndex(pt_index + i)];
                for (0..self.points.items.len) |j| {
                    if (i == j) continue;
                    const p1 = &self.points.items[self.pointIndex(pt_index + j)];
                    const distance = p0.position.distance(p1.position);
                    if (distance < self.point_spacing * point_force) {
                        const center = p0.position.lerp(p1.position, 0.5);
                        {
                            const difference = p1.position.subtract(center);
                            p1.position = center.add(difference.normalize().scale(self.point_spacing * point_force / 2));
                        }
                        {
                            const difference = p0.position.subtract(center);
                            p0.position = center.add(difference.normalize().scale(self.point_spacing * point_force / 2));
                        }
                    }
                }
            }
        }
    }

    pub fn runFabrik(self: *Game) void {
        // we take the point at the other end of the loop, and do fabrik
        // that point will have 2 positions, one from each path
        // ex: 12-11-10...26, 12-13-14...26
        // then take the average of those two points, and work the other way
        // iterations should be odd, so that the final iteration gets to have
        // the head at the correct position
        const pt_index = self.hovered_point orelse return;
        const opposite_index = (pt_index + (self.points.items.len / 2)) % self.points.items.len;
        var start_pos = self.points.items[pt_index].position;
        _ = &start_pos;
        const fabrik_iterations = 9;
        for (0..fabrik_iterations) |i| {
            const start = if (i % 2 == 0) pt_index else opposite_index;
            self.runFabrikIteration(start, i == fabrik_iterations - 1);
            if (i % 2 != 0) self.points.items[pt_index].position = start_pos;
        }
    }

    pub fn doAction(self: *Game, action: ButtonAction, bindex: usize) void {
        switch (action) {
            .loop_size_increase => {
                for (0..3) |_| {
                    const increase = 4;
                    const pct_increase = helpers.fraction(increase, self.points.items.len);
                    self.move_fraction *= 1 - pct_increase;
                    for (0..increase) |i| {
                        const f = helpers.fraction(i, self.points.items.len);
                        const indexf = @divFloor(f * @as(f32, @floatFromInt(self.points.items.len)), 1.0);
                        const index: usize = @intFromFloat(indexf);
                        const pos0 = self.points.items[self.pointIndex(index)].position;
                        const pos1 = self.points.items[self.pointIndex(index + self.points.items.len - 1)].position;
                        self.points.insert(index, .{ .position = pos0.lerp(pos1, 0.5) }) catch unreachable;
                        self.hovered_point = index;
                        self.runFabrik();
                        self.hovered_point = null;
                    }
                }
            },
            .worker_add,
            => {
                for (0..2) |_| {
                    const offset = self.movers.items[0].fraction;
                    const pos = self.movers.items[0].position.lerp(self.movers.items[self.movers.items.len - 1].position, 0.5);
                    self.movers.append(.{ .position = pos, .fraction = 0 }) catch unreachable;
                    for (self.movers.items, 0..) |*mover, i| {
                        const fract = helpers.fraction(i, self.movers.items.len);
                        mover.fraction = @mod(fract + offset, 1);
                    }
                }
            },
            .worker_speed_increase,
            => {
                self.move_fraction *= 1.5;
                self.anim_progress *= 1.5;
            },
            .quest_complete => {
                const quest = &self.quests.items[bindex];
                quest.claimed = true;
                for (quest.zones_unlocked) |zi| self.zones.items[zi].hidden = false;
                for (quest.quests_unlocked) |qi| self.quests.items[qi].shown = true;
                for (quest.actions) |ac| self.buttons.items[ac].index += 1;
            },
        }
    }

    // updateGame
    pub fn update(self: *Game, ticks: u64) void {
        // clear the arena and reset.
        self.steps += 1;
        _ = self.arena_handle.reset(.retain_capacity);
        self.arena = self.arena_handle.allocator();
        self.ticks = @intCast(ticks);
        if (!self.haathi.inputs.mouse.l_button.is_down) {
            self.hovered_point = null;
            for (self.points.items, 0..) |*point, i| {
                if (self.haathi.inputs.mouse.current_pos.distanceSqr(point.position) < self.point_spacing * self.point_spacing) {
                    self.hovered_point = i;
                    self.hovered_offset = point.position.subtract(self.haathi.inputs.mouse.current_pos);
                    self.hovered_position = point.position;
                    break;
                }
            }
        }
        if (self.hovered_point) |pt_i| {
            if (self.haathi.inputs.mouse.l_button.is_down) {
                const target = self.haathi.inputs.mouse.current_pos.add(self.hovered_offset);
                const moved = self.hovered_position.distance(target);
                const direction = target.subtract(self.hovered_position);
                const max_move: f32 = 1;
                const final = if (moved < self.point_spacing * max_move) target else self.hovered_position.add(direction.normalize().scale(self.point_spacing * max_move));
                const steps = 10;
                for (0..steps + 1) |i| {
                    const fr = helpers.fraction(i, steps);
                    self.points.items[pt_i].position = self.hovered_position.lerp(final, fr);
                    self.runFabrik();
                }
                self.hovered_position = final;
            }
        }
        for (self.movers.items) |*mover| {
            mover.prev_position = mover.position;
            mover.anim_tick += self.anim_progress;
            const max_speed = self.point_spacing * helpers.asf32(self.points.items.len) * self.move_fraction * 2;
            const target = self.getPos(mover.fraction);
            if (target.distanceSqr(mover.position) < (max_speed * max_speed)) {
                mover.position = self.getPos(mover.fraction);
            } else {
                // catch up
                const direction = target.subtract(mover.position);
                mover.position = mover.position.add(direction.normalize().scale(max_speed));
                mover.anim_tick += self.anim_progress;
            }
            mover.fraction -= self.move_fraction;
            if (mover.anim_tick >= 1) {
                mover.sprite_index = (mover.sprite_index + 1) % Mover.SPRITE_COUNT;
                mover.anim_tick = 0;
            }
            if (mover.fraction < 0) mover.fraction += 1;
            if (self.inZone(mover.position)) |zone_i| {
                const zone = &self.zones.items[zone_i];
                if (mover.carrying) |mat| {
                    if (zone.is_consumer) {
                        const success = zone.deliver(mat, self);
                        if (success) self.score += mat.score();
                        mover.carrying = null;
                    }
                } else {
                    if (!zone.is_consumer) {
                        mover.carrying = zone.pickup(self);
                    }
                }
            }
        }
        for (self.buttons.items) |*btn| {
            btn.enabled = btn.index > 0;
            btn.update(self.haathi.inputs.mouse);
            if (btn.clicked) {
                btn.index -= 1;
                self.doAction(@enumFromInt(btn.value), btn.index);
            }
        }
        for (self.quests.items) |*quest| {
            if (!quest.shown) continue;
            const done = self.zones.items[quest.zone_count_index].count;
            quest.completed = done >= quest.reqd;
            quest.button.enabled = quest.completed and !quest.claimed;
            quest.button.update(self.haathi.inputs.mouse);
            if (quest.button.clicked) self.doAction(@enumFromInt(quest.button.value), quest.button.index);
        }
    }
};
