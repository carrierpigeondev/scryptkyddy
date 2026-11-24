# Actors API
## Version 0.0.2 (W.I.P.)

An Actor is an executable that takes the following parameters:

```
$0  : Executable Name (Standard; non-specific to ScryptKyddy)
$1  : Role
$...: Role Parameters
```

An Actor must define the `broadcast` Role, which prints out a new-line separated list of which other Roles the Actor
implements.

The following is a list of all other Roles an Actor may implement:

### Fetch

```
$2  : URL/URI
```

Must write to standard out the contents what has been fetched.

### Install

```
$2  : Output Directory
$3  : Output Name
```

Must read from standard in the contents to install.

Must write to standard out the joined path of where the main file (e.g., an executable) has been written (i.e., Output
Scrypt Path). Does not need to make the main file executable, because might also be used for non-executables (Actors and
Catalogues).

### Integrity

### Compile

### Link

```
$2  : Output Scrypt Path
$3  : Output Symlink path
```

Writes nothing to standard out. Must create working link to the file. The file must be executable.