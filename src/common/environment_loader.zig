const std = @import("std");

pub const EnvironmentVariableResult = struct {
    actor_directory: []const u8,
    catalogue_directory: []const u8,
    universal_scrypt_install_directory: []const u8,
    universal_scrypt_symlink_directory: []const u8,

    /// simply returns false if any of the variables are empty
    // (const because can be left as const, no need for var at all since no other methods on the struct)
    pub fn isComplete(self: *const EnvironmentVariableResult) bool {
        return self.actor_directory.len > 0 and
            self.catalogue_directory.len > 0 and
            self.universal_scrypt_install_directory.len > 0 and
            self.universal_scrypt_symlink_directory.len > 0;
    }
};

pub fn loadEnvironmentVariables(env: *std.process.Environ.Map) EnvironmentVariableResult {
    return .{
        .actor_directory = env.get("SCRYPTKYDDY_ACTORS") orelse "",
        .catalogue_directory = env.get("SCRYPTKYDDY_LOCALCATALOGUES") orelse "",
        .universal_scrypt_install_directory = env.get("SCRYPTKYDDY_SCRYPTS") orelse "",
        .universal_scrypt_symlink_directory = env.get("SCRYPTKYDDY_BIN") orelse "",
    };
}

