# Actors API
## Version 0.0.1

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
$3  : Output Symlink Path
```

Must read from standard in the contents to install.
