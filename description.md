# Depman

## Overview

All files exist in the `depman/` directory relative to the current directory.

- `config.toml` specifies configuration options. (optional)
- `dependencies.toml` specifies your dependencies. (optional)
- `build.nu` file is a Nushell script. This is where you define build/test/run commands to be executed by depman.
- `dependencies.lock` is the lockfile used to pin dependencies with their content hashes. This file is not meant to be edited by the user.

For security, depman executes all commands in a podman container. 

Depman execution is as follows:
1. Depman command creates a podman container and puts the project directory inside.
2. Inside the podman container, the depman script that does the actual job is automatically downloaded and executed. By downloading the script version that matches the one project uses, perfect backwards & forwards compatibility is achieved without security holes and in completely transparent to the user.

## dependencies.toml

Dependencies are specified in this file. If any dependency has a
depman.toml file, first that is executed. Dependencies are referenced by the
user by name. Possible keys for a dependency:

- `url`: https retrieve.
- `repo`: git clone retrieve.
	- `repo.url` = git url.
	- `repo.commit` = specific commit hash.
	- `repo.branch` = specific branch.
- `path`: path in the local filesystem, retrieved with `cp`. If the path points
	to a directory, entire directory is used.
- `rsync`: rsync retrieve url.
- `cmd`: nushell command with output directory given in an environment variable.
- `depman-cmd` = Depman build command to execute. By default doesn't execute
	depman commands in dependencies.

Every dependency supports arbitrarily named variations, specified during command
execution: `linux`, `windows`, `new-branch`, `dev`, `test`, etc. These
variations will be given to commands when a flag of the same name as the
variation is supplied.

## config.toml

#### \[depman\]

- `out-dir`: output directory. Default: `./depman/`
- `cache-dir`: caching directory. Default: `<$out_dir>/cache`

#### \[commands\]
- `<name>.out-dir`: if given, named command uses this out-dir. Default:
	`./<name>`. If a depset it used, default is: `<name>_<depset>`.
- `<name>.fresh-start`: clean the out-dir before execution for the
	command. Default: true

#### \[depsets\]
- `<name>.lock`: A boolean indicating whether a lockfile will be used for dependencies in 
this variation, when that variation is being used. Default: true
- `<name>.lock-list`: If this depset is not locked by default, make an exception for these dependencies and lock them. Default: `[]`
- `<name>.no-lock-list`: Don't lock the given dependencies. In order to use this key, `<name>.lock` must be set to false. Default: `[]`
- `<name>.pass-default`: Pass default depset. Default: true

## dependencies.lock

The file locking source hashes to directory contents hashes.
Depman refuses to proceed and warns the user, showing all changes in the different versions if there's any change in the dependencies.
Depman itself is also pinned in this file.

## build.nu

All environment variables are cleared before `build.nu` is executed, except $env.HOME, $env.DISPLAY and $env.USER. This is to reduce dependence on the environment and to facilitate explicit acquiring of all dependencies.

The build command is executed with two arguments:
```nu
depman build $dep_dirs $source_dir
```

- `$dep_dirs`: A record of {dependency-name: directory} pairs.
- `$source_dir`: The source directory (the directory depman was run from, which is usually the top directory in a repository.)

Working directory of is set to the output directory of the command, which is by default set to `<command>` in the depman output directory.

After `depman.toml` is evaluated and dependencies are retrieved, `depman`
command executes the function in `depman.nu` with the given name.

## Options

```nu
depman --cache <dir> <name>
```

Caches the given directory with the given name. For use in `depman.nu`.

```nu
depman --retrieve <name> <dir>
```

Retrieve the previously cached directory from its name to the specified
directory. For use in `depman.nu`.

```nu
depman --config <path_to_depman.toml>
```

Use an alternate `depman.toml` file.

```nu
depman --overlay <path_to_overlay | record>
```

Merges either a depman.toml file or a record over the current `depman.toml`. The fields in the given file/record will overwrite the fields in the current `depman.toml`.

```nu
depman --help
```

Shows the help text.

## Commands

- `depman init`. Creates a depman.toml file in the current directory.
- `depman`. Shows the help text.
- `depman watch` Watches the dependencies specified in a given variation, and when there's any change executes the given command for that variation.
- User-defined commands in depman.nu.

## FAQ

### Why is using bash scripts for build tasks etc. not supported?
Please take a look at your calendar.

## Contributing

The project is not open to contributions until I finish the stuff in the TODO list below.
After that, please discuss with me before making a PR. I consider this project to be very limited in scope and very minimalistic. Whatever is in the initial release probably won't change much. It's not meant to replace or substitute Nix. It's like the little brother of Nix: far simpler and easier to use, but without all the convenience functions Nix offers to build everything ranging from Rust packages to OS images. Depman is also importantly won't ever be as deterministic as Nix, even though it tries really hard to be as deterministic and reproducible as possible.

## Notes
- Rootless podman inside rootless podman is possible and actually quite easy.

## TODO

- - [ ] Rearchitecture to use containers:
	- - [ ] One small easily auditable widely compatible POSIX-sh part. 
	Runs a rootless podman container with the project directory inside. 
	- - [ ] The actual script running inside the container (spawning containers for build commands.)
	- - [ ] Warn the user when a new depman version is released.
	- - [ ] When downloading the nu script check it with the hardcoded signing key of me.
- - [ ] --cache
- - [ ] --retrieve
- - [ ] --config
- - [ ] --overlay
- - [ ] --help text
- - [ ] watch subcommand
- - [ ] out
- - [ ] commands.out-dir in config.toml
- - [ ] commands.fresh-start in config.toml