# Actors API
## Version 0.0.1-202610301533

An actor is an executable that takes the following parameters:

```
$0  : Executable Name (Standard; non-specific to ScryptKyddy)
$1  : Role
$...: Role Parameters
```

An actor must define the `broadcast` role, which prints out a new-line separated list of which other roles the actor
implements.

The following is a list of all other roles an actor may implement:

### Fetch

```
$2  : URL/URI
```

Must write to standard out the contents what has been fetched.

### Install

```
$2  : Contents
$3  : Output Directory
$4  : Output Symlink Path
```
