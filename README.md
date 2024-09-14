#### Caution!
This project is currently in alpha stage and many of the features described here are not implemented yet.

## What is Depman?

Depman is the simplest possible:
- Project dependency manager
- Build system
- Command/test runner
- CI/CD system

It can replace (or build upon) tools as diverse as Make, Meson, Travis, GH Actions, Just, Bazel or Dagger.

## Features
- General purpose: No assumptions about language, project type, ecosystem, or tooling.
- Flexible: You 'just write a shell script'. There is no DSL or programming language besides Nu.
- Interoperable with any other tool: Depman does everything in a single self contained 'depman/' directory.
- Secure: Everything is fully isolated from your system with rootless containers.
- Reproducible: Every input/dependency is pinned with its content hash, including the container and Depman itself. Every input can be signed too.
- Fast: Caches everything.
- Cross-platform: Works on Linux, MacOS and *uh... wait a sec, do people still use Windows? Let me check...* and Windows.
- Backwards & forwards compatible: Everything runs in a container, so any version of Depman can build a project using any version of Depman.
- Modern: Written in Nushell, a statically typed, compiled, mostly functional cross-platform shell and programming language written in Rust.

### Values
Ordered by priority:

1. Security: Depman will warn you and not proceed if any your dependencies have changed a single bit. It will never auto-update dependencies.
2. Minimalism:
    - In behavior: The usage manual (following two sections in this file) should never exceed 5 minutes in reading time.
    - In implementation: The total LoC should always remain below 1000.
3. Convenience: Wherever isn’t incompatible with the above values, we pursue the most convenient UX.

## The files

All files `depman` uses are in the self-contained `depman/` directory. You can place it anywhere.

```
my-project/
  depman/
    config.toml
    dependencies.toml
	dependencies.lock
    build.nu
	build/
    cache/
```

- `config.toml` (optional) specifies project configuration. 
- `dependencies.toml` (optional) specifies your dependencies.
- `build.nu` is a Nushell script. This is where you define build/test/run/install/whatever commands that will be executed by depman when you run `depman build/test/run/whatever`. These commands are Nushell custom commands.
- `dependencies.lock` is the lockfile used to pin dependencies with their content hashes. It's not meant to be changed by the user.
- `cache/` is the directory where dependencies are cached.
- `build/` is where the artifacts go.

### `dependencies.toml`

Dependencies are specified here. Say you are writing the best text editor in the world:
```toml
[builtin-plugins]
# Repository to `git clone`.
git.url = 'https://github.com/editor/builtin-plugins'
# (optional) Specific branch.
git.branch = 'release'

[community-plugins]
git.url = 'https://github.com/editor/community-plugins'  
# (optional) Specific commit hash.
git.commit = '421fb6f8'

# What if your community-plugins repo is also using Depman to build the plugins?
depman-cmd = 'release'
# This will execute `depman release` in the dependency directory after it's obtained.

[themes]
# URL to download with HTTP/S GET request
http.url = 'https://github.com/editor/community-themes/archive/main.tar.gz' 
# (optional) follow` or `error`. Default: `error`.
http.redirect-mode = 'follow' 

[tutorial-video]
# Local path copied with `cp`.
path = '~/editor-assets/tutorial-linux.mp4'
# You can specify different dependency sets and different sources for each dependency set (depset). Here's how.
# For this dependency, this path will be used instead of the default path when you run `depman build macos`:
macos.path = '~/editor-assets/tutorial-macos.mp4'
# And this path will be used when you run `depman build windows`:
windows.path = '~/editor-assets/tutorial-windows.mp4'

# For every dependency, the source specified without a depset prefix is in the depset named 'default'.

[image-helper]
# Command to execute in nushell, with output directory given in the $out_dir environment variable.
cmd = 'cd ./image-helper; cargo build --release --root $env.out_dir'
windows.cmd = 'cd ./image-helper; cargo build --release --root $env.out_dir --target x86_64-pc-windows-gnu'
macos.cmd = 'cd ./image-helper; cargo build --release --root $env.out_dir --target x86_64-apple-darwin'

# Another depset solely for developing it (compile without --release optimizations)
helper-dev.cmd = 'cd ./image-helper; cargo build --root $env.out_dir'

[download-stats]
# rsync source.
rsync = 'user@best-text-editor.com:/data/download-stats.csv'
```

You've just learned the full dependency specification. There's nothing more to it!

### `config.toml`

This file is entirely optional.

```toml
[depman]
# Output directory for commands. Default: './depman/build/'.
out-dir = './build/'

# Caching directory. Default: './depman/cache'
cache-dir = '~/.cache/'

# The default user-defined command to execute, when no command name is given as argument. Default: none.
default-cmd = 'build'

[commands]
# The output directory for the command to use. Default: './depman/build/<command_name>'
# If a depset is used, default is: './depman/build/<command_name>_<depset_name>'
release.out-dir = '/usr/bin/editor'
test.out-dir = '/usr/bin/editor-unstable'

# Whether to clean the out-dir before the execution. Default: true
test.fresh-start = false

[depsets]
# Whether to use the lockfile for dependencies in this depset.
dev-branch.lock = false

# If this depset is not locked by default, make an exception for these dependencies and lock them
dev-branch.lock-list = [ 'themes', 'image-helper' ]

# Don't lock the given dependencies. In order to use this key, lock value must be true for the depset.
default.no-lock-list = [ 'community-plugins' ]

# The dependencies to include in the depset. By default a depset includes all 
# dependencies, even those which don't have a specified source for the depset. 
# Those dependencies' default source will be used instead.
helper-dev.deps = [ 'image-helper' ] # We don't need other dependencies when developing image-helper.

# You can specify a dependency blacklist for a depset too.
windows.no-deps = [ 'themes' ] # Windows users don't like customization.
# They will feel right at home with the default white on blue theme.

```

### `dependencies.lock`

The file containing source hashes to directory contents hashes.
If there's a single bit of change in the dependencies, Depman refuses to proceed and warns the user, showing the changes between in the different versions.
Depman itself is also pinned in this file.

### `build.nu`

This is the file where you define [custom commands](https://www.nushell.sh/book/custom_commands.html) to be executed

All environment variables are cleared before `build.nu` is executed, except `$env.HOME`, `$env.DISPLAY` and `$env.USER`. This is to reduce dependence on the environment and to encourage explicit acquiring of all dependencies.

The build command is executed with two arguments:
```depman build <dep_dirs> <source_dir>```

- `$dep_dirs`: The table containing dependency name - path pairs.
- `$source_dir`: The source directory (the parent directory of `depman/`)

Working directory is set to the output directory of the command.

## Usage

```
depman {flags} <command> ...(depsets)
```

1. Find the closest `depman/` directory, searching upwards from the current directory.
2. Create a rootless container and mount the source directory (parent directory of `depman/`) into the container. The rest of the process from here runs entirely inside the container.
3. Acquire dependencies specified in `dependencies.toml`. If a dependency set (depset) is given obtain only the dependencies in the specified depset.
4. Execute the `<command>` you defined in `build.nu`, passing it the acquired dependencies' paths, once for every depset given.
5. That's it!

### Flags

-	`--watch`
	
	Watch the source directory (the parent directory of `depman/`) and re-execute the command whenever any file inside changes. 

-	`--dir <path_to_dir>`
	
	Use the specified directory as the `depman/` directory instead of the automatically discovered one.

-	`--overlay <path_to_dependencies_toml | record>`
	
	Merge either the given `dependencies.toml` file or the record with the current `dependencies.toml`. The values in the given file/record will overwrite the fields in the current `dependencies.toml`.

-	`--help`
	
	Show the help text.

### Subcommands
-	`depman cache <item> <name>`
	
	Cache the given directory or file with the given name. You can use this command to manually cache stuff in your commands.

-	`depman retrieve <name> <dir>`
	
	Retrieve a directory cached with `depman cache` with its name to the specified directory.

-	`depman init`: Create an example `depman/` directory in the current directory.

## FAQ

### Why is using a bash based build.sh not supported?
Please take a look at your calendar.

### Why did you create this?
I was building a complex project for a client which started small but soon required a build system. There were many moving parts, C sources to compile, binaries to bundle, static assets to include. Reliability and reproducibility was a requirement. I evaluated the current mainstream build tools: Bazel, Nix, Make, Dagger, Meson, etc. All of them are either too complex, too inconvenient or too inflexible for the job. So I decided to build a zero learning curve, fully general purpose, zero bloat minimal build tool.

## Contributing

Please discuss with me before making a PR. I consider this project to be very limited in scope and very minimalistic. Whatever is in the initial release is not intended to change much. 

It's not meant to replace or substitute Nix. It's like the little brother of Nix: far simpler and easier to use, but without all the convenience functions Nix offers to build everything ranging from GUI apps to OS images.