const std = @import("std");

/// according to API spec:
///   - argv[0] : program name
///   - argv[1] : "integrity"
///   - argv[.] : Undefined, each actor can specify what it needs.
///
/// Although also defined in the API spec (todo: do that)
/// is the provision for argv indices beyond 1 to be arbitrarily defined in the scrypt manifest and fed by scryptkyddy
/// to the actors argv
///
/// for examples:
/// - it wants a checksum from the manifest itself? needs a checksum bytes
/// - it wants get its own checksum from a separate http request? private repo? needs a url (and token)
/// - it wants to use key-based auth ? needs a whatever it needs to get the key
///
/// Furthermore, integrity actor required to write a result to stdout, as is standard for the output of other actors
/// a negative result (checksums do not match) is any result other than "CHECK_TRUE" (which is the only positive result)
///
/// this integrity actor wants:
///   - argv[2] : Sha256 Hash as Checksum (Lowercase Hex)
pub fn integrity(io: std.Io, alloc: std.mem.Allocator, input_contents: []const u8, argv: []const []const u8) ![]u8 {
    _ = io;

    // get the contents from the fetch fed into this in order that it might verify the checksum
    // for reference on how to get the input; see the unzip-actor implementation because this needs to take in the
    // input as a function param since a builtin actor
    var digest: [std.crypto.hash.sha2.Sha256.digest_length]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(input_contents, &digest, .{});

    const hex = std.fmt.bytesToHex(digest, .lower);

    if (std.mem.eql(u8, &hex, argv[2])) {
        return try alloc.dupe(u8, "CHECK_TRUE");
    } else {
        return try alloc.dupe(u8, "CHECK_FALSE"); // convention; not required
    }
}