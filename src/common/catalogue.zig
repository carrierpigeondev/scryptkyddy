const std = @import("std");

pub const RoleType = enum(u8) {
    fetch,
    install,
};

pub const Role = struct {
    role_type: RoleType,
    actor: []const u8,
};

/// typedef for Scrypt so Catalogue can easily act as container for it
pub const Scrypt = struct {
    name: []const u8,
    source: []const u8,
    roles: []Role,
};

/// contains a combined list of catalogue segments and the means to create itself
pub const Catalogue = struct {
    scrypts: []Scrypt,

    pub fn init() !Catalogue {

    }
};