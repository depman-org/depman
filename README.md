### Status Update (April 2025)

This project is not actively developed, and it's not compatible with current versions of Nushell. There are no longer any real world use cases for this project (known to me), which existing other tools aren't more suitable fo. If you are interested in using this project, please contact me.

Much of the codebase was focused around patching and working around the various deficiencies, lacking features and bugs in Nushell. I estimate that if the project was ported to Nushell v0.103.0, up to half of the codebase could be thrown away.

### Caution!
This project is in alpha stage, which means **most** of the features described in *all* following parts of this document are not implemented yet. That said, Depman is self-hosted today and uses itself for its own development, build, testing, and release, all in ~600 lines of code.


## What is Depman?

Depman is the simplest possible:
- Project dependency manager
- Build system
- Command/test runner
- CI/CD system

It can replace or build upon tools as diverse as Make, Meson, Nix, Travis, GH Actions, Just, Bazel, Dagger, and more.

## Features
- **General purpose**: No assumptions about language, project type, ecosystem, or tooling.
- **Flexible**: You 'just write a (nu)shell script'. There is no DSL or programming language to learn.
- **Single script**: Did you ever want to distribute your build system with your project? No? Now you can do it!
- **Self-contained**: Everything Depman does happens in a single self contained 'depman/' directory anywhere in your project.
- **Secure**: Builds are fully isolated from your system with [Syd](https://crates.io/crates/syd) and containers.
- **Reproducible (Repeatable)**: Inputs *and* outputs are pinned with their content hashes.
- **Fast**: Incremental caching.
- **Cross-platform**: Works on Linux, MacOS and Windows.
- **Backwards & forwards compatible**: Any version of Depman can build a project using any version of Depman.
- **Modern**: Written in Nushell, a statically typed, functionally oriented cross-platform shell and programming language written in Rust.

### Design principles
Ordered by priority:

1. **Security**: Depman will stop and warn you if any your dependencies have changed a literal bit. It will never auto-update any input.
2. **Minimalism**:
    - In behavior: The usage manual (following two sections of this file) shouldn't exceed 5 minutes in reading time.
    - In implementation: The total LoC should always remain below 1000.
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
# Command to execute in nushell, with the output directory given in the $env.dep-dir environment variable.
cmd = 'cd ./image-helper; cargo build --release --root $env.dep-dir'
windows.cmd = 'cd ./image-helper; cargo build --release --root $env.dep-dir --target x86_64-pc-windows-gnu'
macos.cmd = 'cd ./image-helper; cargo build --release --root $env.dep-dir --target x86_64-apple-darwin'

# Another depset solely for developing it (compile without --release optimizations)
helper-dev.cmd = 'cd ./image-helper; cargo build --root $env.dep-dir'

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
export def install [$dirs] {
	cd $dirs.dependencies.pragtical
	meson setup --wrap-mode=forcefallback -Dportable=true build
	meson compile -C build
	meson install -C build --destdir $dirs.out
}
```

All environment variables are cleared before a command from `commands.nu` is executed, except `$env.HOME`, `$env.DISPLAY`, `$env.USER` and `$env.PATH`. (You might notice this is the same behavior as `nix-shell`). This is to reduce dependence on the environment and to encourage explicit acquiring of all dependencies.

Your command is executed with two arguments:
```depman install <dirs> <args?>```

- `$dirs.dependencies`: The record containing dependency name - directory pairs.
- `$dirs.source`: The source directory (the parent directory of `depman/`)
- `$dirs.out`: The directory for the command to put artifacts in.
- `$args?`: The arguments passed to the command by the user, if any.
Working directory is set to `$dirs.out`.

## Usage

```
> depman {flags} (command) ...(args)

Subcommands:
depman init       - Initiate Depman in your project.
depman cache      - Cache an item with a key.
depman retrieve   - Retrieve an item from the cache with a key.

Flags:
-s, --depsets <list<string>>   - The dependency sets to obtain their dependencies.
-d, --dir <path>               - Use a different directory for depman to operate in.
-q, --quiet                    - Be quiet unless there is an error. Commands asking for user confirmation will exit with an error.
-n, --no-error-msg             - Don't show error messages (useful for debugging depman)
-v, --version                  - Print the version number
-h, --help                     - Display the help message for this command
-o, --overlay <path, record>   - Overlay either the given dependencies file or the record on top of the current dependencies.toml.
-w, --watch                    - Watch the source directory and re-execute the command whenever any file changes.

Parameters:
command <string>: The command from the commands script to run. (optional)
...args <string>: The arguments to pass to the command.

```

## Installation

1. Install [Nushell](https://www.nushell.sh/book/installation.html)[^1]. 
2. Download the [latest release](https://github.com/depman-org/depman/releases/latest) of Depman and extract it anywhere you want (e.g. `~/.local/bin/`).

If you use `git` or `rsync` to obtain your dependencies, they need to be present on your system as well[^1].

[^1]: This dependency will be removed before v1.

## Building & development

1. Make sure you have Depman installed. See [Installation](#installation).
2. Clone the repo.
```
git clone https://github.com/depman-org/depman.git
```
3. Inside the repo, run `depman prep` to prepare the development environment.

### Commands to build, test and debug

- `depman build`: Build depman (with your system depman)
- `depman build-run ...`: Build depman and run the freshly built depman with given arguments
- `depman test`: Build depman, test that it can build the previous version of depman successfully and that the build result works
- To test error handling:
  - `depman shell-error`: Create a shell error
  - `depman stream-error`: Create a streaming command error
  - `depman rsync-error`: Create a rsync error

## FAQ

### What happens when I run `depman my-command`?
Here's what happens in order:

1. Find the closest `depman/` directory, searching upwards from the current directory.
2. Create a rootless container and mount the source directory (parent directory of `depman/`) into the container. The rest of the process from here runs entirely inside a container, to provide a standardized environment for Depman to operate in across platforms.
3. Obtain the dependencies specified in the `dependencies.toml` file. If you gave a dependency set (depset) with the `--depsets` flag, obtain only the dependencies in the specified depset.
4. Execute the command named `my-command` you defined in `commands.nu` with the appropriate [arguments](#commandsnu). The command is sandboxed with [Syd](https://crates.io/crates/syd) and can't access anything it doesn't need.
5. That's it!

### Why did you create this?
I was building a complex project for a client which started small but soon required a build system. There were many moving parts, C sources to compile, binaries to bundle, static assets to include. Reliability and reproducibility was a requirement. I evaluated the current mainstream build tools: Bazel, Nix, Make, Dagger, Meson, etc. All of them are either too big/complex, too inconvenient or too inflexible for the job. So I decided to build a 5 minute learning curve, fully general purpose, zero bloat minimal build tool.

### Why is using a bash based build script not supported?
Please take a look at your calendar.

To be serious, bash can't provide some of the necessary functionality like modules, structured data flow and built-in coreutils, critical features which enable Depman to be so convenient with its low LoC count and complexity.

### What about Nix?

Nix is the closest tool in spirit to Depman. Here are the tradeoffs:

|                                 | Depman                            | Nix                                                           |
|---------------------------------|-----------------------------------|---------------------------------------------------------------|
| Dependency declaration language | TOML                              | Nix                                                           |
| Build language                  | Nu                                | Nix & Bash                                                    |
| Build sandbox technology        | Bubblewrap                        | [Syd](https://crates.io/crates/syd)                           |
| External build programs         | Directly used, e.g `cargo`        | Used by Nix functions calling them, e.g `pkgs.buildRustCrate` |
| Onboarding/learning time        | 10 minutes                        | 1-2 weeks                                                     |
| Fully general purpose           | Yes                               | Yes                                                           |

## Contributing

Please discuss with me before making a PR. I consider this project to be very limited in scope and very minimalistic. Whatever is in the v1 release is not intended to change much. You can see the current roadmap [here](docs/roadmap.md).
