# Roadmap

### When v1.0.0?
I have other stuff going at the moment, and creating a tool that makes software development both easier and more reliable than established ones like Bazel, Dagger, or Nix is no easy task. I believe Depman, even in its current not fully fleshed out form offers a level of convenience, simplicity (low cognitive load, less code complexity) and a rapid development speed not found in any other tool, and I value that very highly as an indie developer. I'm using Depman on my projects so I have plenty of incentive to keep working on it. If you insist on a date, hopefully before 2026 ;)

The following is a list of items to be completed before the v1 release. Items are removed from the list as they are completed.

## TODOs for v1.0

- Implement containerization, by dividing Depman into two parts:
	- One small easily auditable widely compatible POSIX-sh shell script that launches the main container for Depman to run in.
		- Run a rootless podman container with the project directory inside.
	- The script running inside the container doing the actual job, obtaining dependencies and spawning build jobs with Syd for build commands.
		- Warn the user when a new depman version is released.
		- When downloading depman script check it with a hardcoded signing key.
- Subcommands
	- cache
	- retrieve
	- obtain
	- update
- Flags
	- --overlay
	- --watch
-  Signing support for dependencies to be able to confirm authenticity when updating them..
-  Check whether we are using unsanitized user input as filename anywhere (this should be built into nu_livr).
-  Check for safety against hash collision attack.
-  Implement `nu_livr` and move as much input validation to it as possible.
-  Create and use an errors-as-values based error handling module.
-  Don't parse all the files every run, even though they take little time, cache the parsing results.
-  Nix packages and flakes accepted as a dependency type.
	- The reason why Nix and Depman packages are allowed as recursive dependencies is because only these two guarantee build inputs remain the same, by either locking inputs & using a purely functional DSL or locking both inputs and the outputs.
-  Full idempotency.
	- We are probably already fully idempotent. Implement tests for it.
-  Implement the rules in the "Reliable Nu" document.