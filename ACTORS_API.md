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

If the Output Symlink Path is blank (an empty string) then the Actor must not try to create the file. Furthermore, the
Actor must return success even if the symlink already exists (so must properly handle file exists errors if a symlink
creation can return such an error).

It is expected behavior for a functional symlink to not be created on the Windows operating system, because Windows does
not support symlink creation as do Linux-based operating systems. It is permissible behavior for an Actor to thus not
create a symlink, try and fail to create a symlink, or warn the user that a symlink is not created; but the Install Role
ought not to create another form of link to the file on Windows.

### Integrity

### Compile

### Link

```
$2  : Output Scrypt Path
$3  : Output Symlink path
```