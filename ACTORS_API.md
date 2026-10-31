# Actors API
## Version 0.0.1-202610301533

An actor is an executable that takes the following parameters:

```
$0  : Executable Name
$1  : Role
$...: Role Parameters
```

An actor must define the `broadcast` role, which prints out a new-line separated list of which other roles the actor
implements.

The following is a list of all other roles an actor may implement:

### Fetch

```
$2  : URL
$3  : Full Output Path
```

### Install