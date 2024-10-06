### Caution!
This project is in alpha stage. This means many of the features below are not implemented yet.

## What is Depman?

Depman is the simplest possible:
- Project dependency manager
- Build system
- Command/test runner
- CI/CD system

It can replace (or build upon) tools as diverse as Make, Meson, Nix, Travis, GH Actions, Just, Bazel or Dagger.

## Features
- **General purpose**: No assumptions about language, project type, ecosystem, or tooling.
- **Flexible**: You 'just write a shell script'. There is no DSL or programming language (besides Nushell).
- **Interoperable**: Everything Depman does happens in a single self contained 'depman/' directory anywhere in your project.
- **Isolated**: Everything is fully isolated from your system with rootless containers.
- **Reproducible (Repeatable)**: Inputs *and* outputs are pinned with their content hashes.
- **Fast**: Caches as much as possible.
- **Cross-platform**: Works on Linux, MacOS and Windows.
- **Backwards & forwards compatible**: Any version of Depman can build a project using any version of Depman.
- **Modern**: Written in Nushell, a statically typed, functionally oriented cross-platform shell and programming language written in Rust.

### Values 
Ordered by priority:

1. **Security**: Depman will warn you and not proceed if any your dependencies have changed a literal bit. It will never auto-update dependencies.
2. **Minimalism**:
    - In behavior: The usage manual (following two sections of this file) shouldn't exceed 5 minutes in reading time.
    - In implementation: The total LoC should remain below 1000.
3. **Convenience**: The most convenient UX possible that gets out of your way and lets you do your job with the least amount of friction.

## The files

All files `depman` uses are in the self-contained `depman/` directory.

```
my-project/
  depman/
    config.toml
    dependencies.toml
	dependencies.lock
    commands.nu
	artifacts/
    cache/
```

- `config.toml` (optional) specifies project configuration. 
- `dependencies.toml` (optional) specifies your dependencies.
- `commands.nu` is a Nushell script. This is where you define your build, test, run, ... commands.
- `dependencies.lock` is the lockfile used to pin dependencies with their content hashes.
- `cache/` is the caching directory.
- `artifacts/` is where the build artifacts go.

### `dependencies.toml` *(optional)*

Dependencies are specified in this file. Say you are writing the best text editor in the world:
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
# URL to download with HTTP/S GET request.
http.url = 'https://github.com/editor/community-themes/archive/main.tar.gz' 
# (optional) 'follow' or 'error'. Default: 'error'.
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
# Command to execute in nushell, with the output directory given in the $out_dir environment variable.
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

### `config.toml` *(optional)*

Commands, depsets and depman configuration for the project.

```toml
[depman]
# Output directory for commands. Default: './depman/build/'.
out-dir = '/usr/bin/'

# Caching directory. Default: './depman/cache'
cache-dir = '~/.cache/'

# The default user-defined command to execute, when no command name is given as argument. Default: none.
default-command = 'build'

[commands]
# The output directory for the command to use. Default: './depman/artifacts/<command_name>'
# If a depset is used, default is: './depman/artifacts/<command_name>_<depset_name>'
release.out-dir = '/usr/bin/editor'
test.out-dir = '/usr/bin/editor-unstable'

# Whether to clean the command output directory before the next execution. Default: true
test.fresh-start = false

[depsets]
# Whether to use the lockfile for dependencies in this depset. Default: true
dev-branch.lock = false

# If this depset is not locked by default, make an exception for these dependencies and lock them. Default: none.
dev-branch.lock-list = [ 'themes', 'image-helper' ]

# Don't lock the given dependencies. In order to use this key, lock value must be true for the depset. Default: none.
default.no-lock-list = [ 'community-plugins' ]

# The dependencies to include in the depset. By default a depset includes all 
# dependencies, even those which don't have a specified source for the depset. 
# Those dependencies' default source will be used instead.
helper-test.deps = [ 'image-helper' ] # We don't need other dependencies when developing image-helper.

# You can specify a dependency blacklist for a depset too.
windows.no-deps = [ 'themes' ] # Windows users don't like customization. They will feel right at home with the default white text on blue background theme.
```

### `dependencies.lock`

The file containing source hashes to directory contents hashes.
If there's a single bit of change in the dependencies, Depman refuses to proceed and warns the user, showing the changes between in the different versions.
Depman itself is also pinned in this file.

### `commands.nu`

This is the file where you define [commands](https://www.nushell.sh/book/custom_commands.html) to execute.

Here's an example file defining an `install` command to build and install [Pragtical](https://github.com/pragtical/pragtical?tab=readme-ov-file#quick-build-guide):

```nu
export def install [dependency_dirs, source_dir, out_dir] {
	cd $dependency_dirs.pragtical
	meson setup --wrap-mode=forcefallback -Dportable=true build
	meson compile -C build
	meson install -C build --destdir $out_dir
}
```

All environment variables are cleared before a command from `commands.nu` is executed, except `$env.HOME`, `$env.DISPLAY`, `$env.USER` and `$env.PATH`. (You might notice this is the same behavior as `nix-shell`). This is to reduce dependence on the environment and to encourage explicit acquiring of all dependencies.

Your command is executed with three arguments:
```depman install <dependency_dirs_dirs> <source_dir> <out_dir>```

- `$dependency_dirs`: The record containing dependency name - directory pairs.
- `$source_dir`: The source directory (the parent directory of `depman/`)
- `$out_dir`: The directory for the command to put artifacts in.

Working directory is set to `$out_dir`.

## Usage									

```
depman {flags} <command> ...(depsets)
```

#### Execution:
1. Find the closest `depman/` directory, searching upwards from the current directory.
2. Create a rootless container and mount the source directory (parent directory of `depman/`) into the container. The rest of the process from here runs entirely inside the container.
3. Acquire dependencies specified in `dependencies.toml`. If a dependency set (depset) is given obtain only the dependencies in the specified depset.
4. Execute the `<command>` you defined in `commands.nu` with the obtained dependencies' locations given as argument.
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
	
	Cache the given directory or file with the given name. You can use this command to manually cache items which are compute heavy to generate in commands.nu.

-	`depman retrieve <name> <dir>`
	
	Retrieve a directory cached with `depman cache` with its name to the specified directory.

-	`depman init`: Create an example `depman/` directory in the current directory.

## FAQ


### Why did you create this?
I was building a complex project for a client which started small but soon required a build system. There were many moving parts, C sources to compile, binaries to bundle, static assets to include. Reliability and reproducibility was a requirement. I evaluated the current mainstream build tools: Bazel, Nix, Make, Dagger, Meson, etc. All of them are either too complex, too inconvenient or too inflexible for the job. So I decided to build a zero learning curve, fully general purpose, zero bloat minimal build tool.

### Why is using a bash based build script not supported?
Please take a look at your calendar.

### What about Nix?

Nix can indeed do everything Depman can do. Depman can also build upon Nix and benefit from its strengths where it's easier to do something in Nix than in Depman, such as when building OS images. Here are the tradeoffs.

|                                 | Depman                            | Nix                                                           |
|---------------------------------|-----------------------------------|---------------------------------------------------------------|
| Dependency declaration language | TOML                              | Nix                                                           |
| Build language                  | Nu                                | Nix & Bash                                                    |
| External build programs         | Directly used, e.g `cargo`        | Used by Nix functions calling them, e.g `pkgs.buildRustCrate` |
| Onboarding/learning time        | 5 minutes                         | 1-2 weeks                                                     |
| Fully general purpose           | Yes                               | Yes                                                           |

## Contributing

Please discuss with me before making a PR. I consider this project to be very limited in scope and very minimalistic. Whatever is in the v1 release is not intended to change much. You can see the current roadmap [here](./roadmap.md).