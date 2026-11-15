# ScryptKyddy

ScryptKyddy is a hackable package manager, written in the [Zig programming language](https://ziglang.org/).

## Usage Notes

See `ACTORS_API.md` for docs on how to make your own Actors.

ScryptKyddy comes compiled with two builtin Actors: `http-actor` and `single-file-write-actor`. Whereas typically Actors
are individual executables, such as those [here](https://github.com/carrierpigeondev/extra-actors) which needs to be
built separately, the builtin Actors are compiled alongside ScryptKyddy itself (located within `/src/builtin-actors`)
and as such do not follow the same construction that other Actors should (e.g., return `[]u8` rather than write to
standard out), yet still remain compatible when used with other Actors.

`/.config` is a temporary directory of this project that contains example Catalogues.