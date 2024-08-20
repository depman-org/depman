# Depman

## depman.toml
Dependencies are specified in depman.toml file. If any dependency has a depman.toml file, first that is executed. Dependencies are referenced by the user by name. Possible keys for a dependency:
- `url`: https retrieve.
- `repo`: git clone retrieve.
	- `repo.url` = git url.
	- `repo.commit` = specific commit hash.
	- `repo.branch` = specific branch.
- `path`: path in the local filesystem, retrieved with `cp`. If the path points to a directory, entire directory is used.
- `rsync`: rsync retrieve url.
- `cmd`: command with output directory given in an environment variable.

Every dependency supports arbitrarily named variations, specified during command execution: `linux`, `windows`, `new-branch`, `dev`, `test`, etc. These variations will be given to commands when a flag of the same name as the variation is supplied.

This step keeps all download artifacts in the cache directory.
1. Checks for presence of the download artifact, name specified in lockfile. If it exists, doesn't download again, only checks the hash.
2. If it doesn't exist, downloads it and checks the hash with the one in the lockfile.
3. If it matches, unpacks it to the centralized unpack directory.
4. If it has a build.nu file, gets the dependencies from its deps.nuon and acquires them, putting them in a subdirectory of the central dependency artifact and unpack directory named after the dependency. Then executes its build.nu main build function with the necessary arguments.
5. Executes our build.nu with the necessary arguments. (the record which specifies the filesystem locations of the build artifacts)

#### \[depman\] keys
- `version`: depman version. Download the appropriate depman version signed by key included with every distribution. Perfect backwards & forwards compatibility.
- `out-dir`: output directory. Default: `'./build'`
- `overlays.<name>.lock`: Whether a lockfile will be used for dependencies in this variation set, when that variation set is being used. Default: true
- `commands.<name>.out-dir`: if given, named command uses this out-dir.
- `commands.<name>.fresh-start`: clean the out-dir before execution for the command. Default: true
- `cache-dir`: caching directory. Default: ~/.cache

## depman.lock
Internally it locks URLs to directory contents hash with a version-controlled lockfile, and refuses to proceed if there's a change.
Usage of lockfile can be disabled altogether with --no-lockfile.

## depman.nu

Given functions in the file are executed. E.g `depman build` executes the build function in depman.nu in the current directory, after depman.toml is evaluated.
Working directory is set to build directory.

## Options

```nu
depman --cache <dir> <name>
```
Caches the given directory with the given name. For use in depman.nu.

```nu
depman --retrieve <name> <dir>
```
Retrieve the previously cached directory from its name to the specified directory. For use in depman.nu

```nu
depman --config <path_to_depman.toml>
```
Use an alternate depman.toml file.

```nu
depman --overlay <path_to_overlay | record>
```
Overlay either a depman.toml file or a record over the current depman.toml.
