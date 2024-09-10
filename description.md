# Depman

\# TODO: We need to support fully recursive execution. Building multiple artifacts with different devsets with a single command. For this, if we can make command functions fully self contained, they can call each other. If this isn't the best maybe a function can call another with `depman other_cmd` directly inside. For this depman should take into account the pwd correctly, somehow. with env var? with flag? something more automatic? wouldnt self contained functions just work?

\# TODO: -d might specify a list too? Built against every one of them?

\# TODO: I think that depman.nu shouldn't be made aware which depset is passed in.

\# TODO: Should commands themselves be able to specify a default depset inside? Maybe this should be done from depman.commands. Mahbe commands should be spun off as separate key.

## depman.toml
Dependencies are specified in depman.toml file. Dependencies are referenced by the user by name. Possible keys for a dependency:
- `url`: https retrieve.
- `repo`: git clone retrieve.
	- `repo.url` = git url.
	- `repo.commit` = specific commit hash.
	- `repo.branch` = specific branch.
- `path`: path in the local filesystem, retrieved with `cp`. If the path points to a directory, entire directory is used.
- `rsync`: rsync retrieve url.
- `cmd`: command with output directory given in an environment variable.
- `depman-cmd`: After acquiring the dependency, execute depman in that dependency folder with the given command and use the resulting directory.

Every dependency supports arbitrarily named depsets, specified during command execution: `linux`, `windows`, `new-branch`, `dev`, `test`, etc. These depsets will be given to commands with the flag --depset (-d).

This step keeps all download artifacts in the cache directory.
1. Checks for presence of the download artifact, name specified in lockfile. If it exists, doesn't download again, only checks the hash.
2. If it doesn't exist, downloads it and checks the hash with the one in the lockfile.
3. If it matches, unpacks it to the centralized unpack directory.
4. If it has a build.nu file, gets the dependencies from its deps.nuon and acquires them, putting them in a subdirectory of the central dependency artifact and unpack directory named after the dependency. Then executes its build.nu main build function with the necessary arguments.
5. Executes our build.nu with the necessary arguments. (the record which specifies the filesystem locations of the build artifacts)

#### \[depman\] keys
- `version`: depman version. Download the appropriate depman version signed by key included with every distribution. Perfect backwards & forwards compatibility.
- `out-dir`: output directory. Default: `'./build'`
- `commands.<name>.out-dir`: if given, named command uses this out-dir.
- `commands.<name>.fresh-start`: clean the out-dir before execution for the command. Default: true
- `cache-dir`: caching directory. Default: ~/.cache
- `release-cmd`: Depman command for release. If specified, # TODO basically default command. The idiomatic help interface is --help. I think we can do it bro.

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
Retrieve the previously cached directory from its name to the specified directory. For use in depman.nu.

```nu
depman --config <path_to_depman.toml>
```
Use an alternate depman.toml file.

```nu
depman --overlay <path_to_overlay | record>
```
Overlay either a depman.toml file or a record over the current depman.toml.
