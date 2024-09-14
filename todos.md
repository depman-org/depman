## TODOS

- - [ ] Rearchitecture to use containers:
	- - [ ] One small easily auditable widely compatible POSIX-sh part. 
	Runs a rootless podman container with the project directory inside. 
	- - [ ] The actual script running inside the container (spawning containers for build commands.)
	- - [ ] Warn the user when a new depman version is released.
	- - [ ] When downloading the nu script check it with the hardcoded signing key of me.
- - [ ] cache subcommand
- - [ ] retrieve subcommand
- - [ ] --dir flag
- - [ ] --overlay flag
- - [ ] --help flag
- - [ ] --watch flag
- - [ ] out
- - [ ] commands.out-dir in config.toml
- - [ ] commands.fresh-start in config.toml
- - [ ] Optional signing support for dependencies. There are cases where signing is more preferable than content hashes.

## Notes
- Rootless podman inside rootless podman is possible and actually quite easy.
- Should commands themselves be able to specify a default depset they want to run with in the config file?
