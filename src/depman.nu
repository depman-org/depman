#!/usr/bin/env -S nu --no-config-file --no-history

const NAME = 'Depman'
const VERSION = '0.2.0'
const NU_VERSION = '0.98.0'
const GITHUB_URL: string = 'https://github.com/rayanamal/depman'
const CLI_NAME = $NAME | str downcase
const DEPMAN_DIR: path = $CLI_NAME
const default_paths = {
	out-dir: 'artifacts/'
	cache-dir: 'cache/'
	dependencies_file: 'dependencies.toml'
	lockfile: 'dependencies.lock'
	commands_script: 'commands.nu'
}

bundle-file nuitron 'mod.nu'
use ../depman/cache/nuitron *

$env.nuitron_exit_on_error = true
$env.nuitron_error_exit_code = $env.DEPMAN_ERROR_CODE? | default 1   # TODO: Document this.
let nu_version: string = try { (version).version } catch { 'unknown' }
if $nu_version != $NU_VERSION {
	error $"Your Nushell version is not compatible with ($NAME). Required Nushell version is ($NU_VERSION | style green).\nYou can download different versions of Nushell here: https://github.com/nushell/nushell/releases"
}

# Depman is the simplest possible project dependency manager, build system and command runner.
# Documentation: https://github.com/rayanamal/depman
def main [
	command?: string               # The command from the commands script to run.
	...args: string                # The arguments to pass to the command.
	--depsets (-s): list<string>   # The dependency sets to obtain the dependencies in.
	--dir (-d): path               # Use a different directory for depman to operate in
	--quiet (-q)                   # Be quiet unless there is an error. Commands asking for user confirmation will exit with an error.
	--no-error-msg (-n)            # Don't show error messages (useful for debugging depman)
	--version (-v)                 # Print the version number
]: nothing -> nothing { ignore
	if $version {
		say $"($NAME) version: ($VERSION | style green)"
		exit
	}
	if ($command == null) {
		say -i 1 $"Welcome to ($NAME | style light_green_bold)!\n"
		say $"Run ($CLI_NAME + ' init' | ft cmd) to get started, or ($CLI_NAME + ' --help' | ft cmd) to see the command description."
		exit
	}
	$env.nuitron_shut_up = $quiet
	let depsets: list<string> = $depsets | do-if ($in | is-empty) { ['default'] }
	let dir: path = (
		$dir 
		| default (find-dir $DEPMAN_DIR)
		| default ([. $DEPMAN_DIR] | path join)
	)
	if not ($dir | path exists) {
		if not $quiet {
			say $"No ($dir | path basename | ft dir) directory found. Do you want to create one at path ($dir | ft dir)? \(Y/n\)"
			[Yes No] | input list -f
			| if $in == 'Yes' {
				main init
			}
			exit
		} else {
			exit 1
		}
	}
	let config_defaults: record = (
		$default_paths
		| items {|key, value|
			{$key: ([$dir $value] | path join)}
		}
		| into record
		| insert default-command null
	)
	let config_toml: path = [ $dir 'config.toml'] | path join
	let config = (
		if ($config_toml | path exists) {
			open-toml $config_toml
		} else { {} }
	)
	let depman_config = parse_depman_config $config $config_defaults
	$depman_config
	| select out-dir cache-dir
	| items {|_, path| ensure-dir $path}

	if not ($depman_config.commands_script | path exists) {
		error --title 'No commands file' $"Can't find a ($depman_config.commands_script | path basename | ft file) file in ($dir | ft dir)." --hint $"Run '($'($CLI_NAME) init')' to create a starting template."
	}
	let dep_locks: any = parse_lockfile
	let all_commands: table<name: string, fresh-start: bool, out-dir: path> = parse_commands $config
	let command: string = $command | default $depman_config.default-command
	err-if ($command not-in $all_commands.name) $"The given command ($command | ft command) cannot be found in ($depman_config.commands_script | ft)."
	let dependencies = parse_dependencies
	let all_depsets = parse_depsets $config $dependencies
	$depsets
	| all-in $all_depsets.name --error {|depset| $"The specified depset ($depset | ft depset) cannot be found in ($config_toml | ft) or ($depman_config.dependencies_file | ft)."}
	$depsets
	| each {|depset|
		let depset_config = (
			$all_depsets
			| where name == $depset
			| get 0
		)
		$depset_config.deps
		| each {|dep_name|
			let source: record = (
				$dependencies
				| where name == $dep_name
				| get 0.sources
				| with {|sources|
					where depset == $depset
					| do-if ($in | is-empty) { $sources | where depset == 'default' }
				}
				| get 0.value
			)
			
			{name: $dep_name}
			| insert src-hash {|rec|
				let prefix = $rec.name | str substring ..30 | $in + '_'
				$source
				| to nuon 
				| hash md5 
				| str substring ..(255 - ($prefix | str length))
				| $prefix + $in
				| path sanitize
			}
			| insert dir {|rec| [$depman_config.cache-dir $rec.src-hash] | path join}
			| insert lock (determine_lock $depset_config $dep_name)
			| merge (compute_cmd $in.dir $source)
		}
		| run-each {|dep|
			if not ($dep.dir | path exists) { mkdir $dep.dir }
		}
		| run-if ($in | all {ls -a $in.dir | is-not-empty}) { say -i 1 $'All dependencies for depset ($depset | ft depset) are already obtained.' }
		| run-if ($in | any {ls -a $in.dir | is-empty}) {
			say -i 1 'Obtaining dependencies for depset ' ($depset | ft depset)
		}
		| run-each {|dep|
			mkdir $dep.dir
			if (ls -a $dep.dir | is-empty) {
				[
					(say -o -i 2 "Obtaining dependency " ($dep.name | ft dep) '...')
					...($dep.cmd-str | lines | each {|line| say -o -i 3 --ansi grey58 $line })
				]
				| str join "\n"
				| say $in "\n"
				try { 
					do $dep.cmd
					| if ($in | is-type --structured 'record<stdout: string, stderr: string, exit_code: int>' ) {
						if $in.exit_code != 0 {
							error $in.stderr --title $"Can't obtain the dependency ($dep.name | ft dep)"
						}
					}
				} catch {|err|
					$err
					| parse-error
					| update title {$"Can't obtain the dependency ($dep.name | ft dep): ($in | style attr_bold)" }
					| error $in
				}
			}
		}
		| run {|deps|
			say -i 1 $"Running the command ($command | ft command)..."
			let dependency_dirs = $deps | select name dir | transpose -rd
			let source_dir: path = $dir | path parse | get parent | err-if ($in == null) $"You can't use the system root directory as the ($NAME) directory."
			let out_dir: path = (
				$all_commands
				| where name == $command
				| get 0.out-dir
				| default (
					$depman_config.out-dir
					| path join (
						if $depset == default { $command } else { $"($command)_($depset)" } 
					)
				)
			)
			if ($all_commands | where name == $command).0.fresh-start {
				rm -rf $out_dir
				mkdir $out_dir
			}

			let nuitron_path = ([$depman_config.cache-dir nuitron.nu] | path join)
			bundle-file --base64 nuitron mod.nu
			| decode new-base64
			| save -f $nuitron_path
			# TODO: there's a sql injection attack in how you use nuitron_path and commands_script down there. Preventable by not allowing any '# sequence in these paths.
			# TODO: remove the cache dir from below when the depman cache and depman retrieve commands are implemented. Change commands.nu accordingly too.
			let script = $"
				let input = $in | from nuon
				load-env $input.env
				let dirs = $input.dirs
				let args = $input.args
				use r#'($nuitron_path)'# *
				use r#'($depman_config.commands_script)'#
				cd $dirs.out
				try {(
					if ($args | is-not-empty) {
						$'commands ($command) $dirs $args'
					} else {
						$'commands ($command) $dirs'
					}
				)} catch {|err|
					$err
					| parse-error
					| to json --raw
					| print $in
					exit \($err.exit_code? | default 1\)
				}
			"
			
			{ 
				dirs: {dependencies: $dependency_dirs, source: $source_dir, out: $out_dir, cache: $depman_config.cache-dir} 
				args: $args
				env: {nuitron_exit_on_error: $env.nuitron_exit_on_error, nuitron_error_exit_code: $env.nuitron_error_exit_code}
			}
			| to nuon
			| nu --stdin -c $script
			| tee {print}
			| tee -e {print}
			| complete
			| with {|result|
				if $result.exit_code? != 0 {
					try {
						$result.stdout
						| lines
						| last
						| from json
						| with {|error_rec|
							print "\e[F\e[2K\e[F\e[2K"
							$error_rec
						}
					} catch {|err|
						{ message: $result.stderr }
					}
					| upsert title {
						if $in != null { ': ' + $in } else { '' }
						| $"Error running ($command | ft command)" + $in
					}
					| if not $no_error_msg { 
						error $in
					} else { exit 1 }
				} else {
					say ""
					say -i 1 $"Successfully ran ($command | ft command)."
					if ($out_dir | path exists) and (ls $out_dir | is-not-empty) {
						say -i 1 $"Command artifacts are located in ($out_dir | ft dir)."
					}
				}
			}
		}
	}

	def join_cmd_output [stdout: string, stderr: string]: nothing -> string { ignore
		[$stdout $stderr]
		| each { str trim -c (char newline) }
		| str join "\n"
		| str trim -c (char newline)
	}

	def determine_lock [
		depset_config: record
		dep_name: string
	]: nothing -> bool { ignore
		let in_lock_list = $dep_name in $depset_config.lock-list
		let in_no_lock_list = $dep_name in $depset_config.no-lock-list
		let default = $depset_config.lock
		$in_lock_list or (not $in_lock_list and not $in_no_lock_list and $default)
	}
	
	def compute_cmd [
		cache_dir: path
		source_value: record<type, description, depman-cmd> 
	]: nothing -> record<cmd: closure, cmd-str: string> { ignore
		{$source_value.type: $source_value.description}
		| match $in {
			{git: $repo} => {
				if $repo.branch? != null {
					{
						cmd: { git clone -b $repo.branch? $repo.url $cache_dir | complete },
						cmd-str: $"git clone -b '($repo.branch?)' '($repo.url)' '($cache_dir)'"
					}
				} else if $repo.commit? != null {
					{
						cmd: { 
							do { git clone $repo.url $cache_dir | complete }
							| do-if ($in.exit_code == 0) { git -C $cache_dir checkout $repo.commit? | complete }
						},
						cmd-str: $"git clone '($repo.url)' '($cache_dir)' \ncd $cache_dir\ngit checkout '($repo.commit?)'"
					}
				} else {
					{
						cmd: { git clone $repo.url $cache_dir | complete },
						cmd-str: $"git clone '($repo.url)' '($cache_dir)'"
					}
				}
			},
			{http: $request} => {
				let redirect_mode: string = $request.redirect-mode? | default 'error'
				let file_path: path = [$cache_dir ($request.url | url to-filename )] | path join
				{
					cmd: { http get --redirect-mode $redirect_mode $request.url | save -f $file_path },
					cmd-str: $"http get --redirect-mode '($redirect_mode)' '($request.url)' \n| save -f '($file_path)'"
				}
			},
			{path: $path} => {
				let path: path = $path | path expand --strict
				{ 
					cmd: {cp -r ($path) ($cache_dir)},
					cmd-str: $"cp -r ($path) '($cache_dir)'"
				}
			},
			{rsync: $source} => {
				let source = $source | path expand --strict | str trim -r -c '/'
				{
					cmd: {rsync -az $source $cache_dir | complete },
					cmd-str: $"rsync -az '($source)' '($cache_dir)'"
				}
			},
			{cmd: $command} => {
				cmd: { $env.dep-dir = $cache_dir; nu -c $command | complete },
				cmd-str: $"nu -c '($command)'"
			}
		}
	}

	def parse_depsets [config: record, dependencies: any]: nothing -> table<name: string, lock: bool, lock-list: list<string>, no-lock-list: list<string>, deps: list<string>> { ignore	
		$config.depsets?
		| default {}
		| transpose name value
		| do-if ($dependencies != null) {|depsets|
			$dependencies
			| get sources
			| flatten
			| get depset
			| uniq
			| wrap name 
			| insert value {{}}
			| transpose -r
			| merge ($depsets | transpose -r)
			| transpose name value
		}
		| each {|it|
			$it.value
			| check-type record -m {|value, value_type| $"The value specified for depset ($it.name | ft depset) in ($config_toml | ft) is invalid: \n($value) \n\nThe value must be a record specifying the configuration for the dependency set."}
			| run  {
				columns
				| all-in  ['lock' 'lock-list' 'no-lock-list' 'deps' 'no-deps'] --error {|key, valid_keys| $"Unrecognized key ($key | ft input) found in the configuration of the depset ($it.name | ft depset) in ($config_toml | ft). Valid keys are one of ($valid_keys | recount)." }
			}
			| err-if ((type-of $in.deps?) == 'list' and ($in.deps? | is-empty)) "The value given for key ($"depsets.($it.name).deps" | ft key) in ($config_toml | ft) is an empty list. A dependency set must contain at least one dependency."
			| defaults {
				lock: true,
				lock-list: [],
				deps: [],
				no-lock-list: [],
				no-deps: [],
			}
			| run {|value|
				$value.lock
				| check-type bool -m {|value, value_type| $"The value given for key ($"depsets.($it.name).lock" | ft key) in ($config_toml | ft) has a type of ($value_type | ft type): \n($value) \n\nType of the value must be ('boolean' | ft type)."}
				[lock-list no-lock-list deps no-deps]
				| each {|key|
					$value
					| get ([$key] | into cell-path)
					| check-type --structured 'list<string>' -m {|value, value_type, accepted_types| $"The value given for key ($'depsets.($it.name).($key)' | ft key) in ($config_toml | ft) has a type of ($value_type | ft type): \n($value) \n\nType of the value must be ($accepted_types)."}	
				}
				$value 
				| select lock-list no-lock-list
				| items {|key, value|
					$value 
					| filter {$in not-in $dependencies.name}
					| err-if ($in | is-not-empty) $'The dependency "($in.0?)" specified in "($config_toml)" for the ($key) for depset "($it.name)" cannot be found in "($depman_config.dependencies_file)".'
				}
				err-if ($value.lock == false and ($value.no-lock-list | is-not-empty)) $'You set both "depsets.($it.name).lock" to false and "depsets.($it.name).no-lock-list" to a non-empty list in "($config_toml)". They are mutually exclusive.'
				err-if (($value.deps | is-not-empty) and ($value.no-deps | is-not-empty)) $'You set both "depsets.($it.name).deps" and "depsets.($it.name).no-deps" in "($config_toml)". They are mutually exclusive.'
				err-if ($value.lock == true and ($value.lock-list | is-not-empty)) $'You set both "depsets.($it.name).lock" to true and "depsets.($it.name).lock-list" to a non-empty list in "($config_toml)". They are mutually exclusive.'
			}
			| update deps {|value|
				do-if ($in | is-empty) {
					$dependencies.name
					| filter {$in not-in $value.no-deps}
				}
			}
			| reject no-deps
			| { name: $it.name, ...$in }
		}
	}
 
	def parse_commands [config: record]: nothing -> table<name: string, fresh-start: bool, out-dir: path> { ignore
		def parse_commands_script []: nothing -> list<string> { ignore
			nu -c $"
				use ($depman_config.commands_script);
				scope modules
				| where name == 'commands'
				| get commands.0.name
				| to nuon
			"
			| complete
			| do-if ($in.exit_code != 0) {
				error ($"Error parsing the commands script ($depman_config.commands_script | ft file).\n($in.stderr)") --title $"Can't parse ('commands.nu' | ft file)"
			}
			| get stdout
			| from nuon
		}
		let defined_commands = parse_commands_script
		$config.commands?
		| default {}
		| transpose name value
		| run {|commands|
			$commands.name
			| all-in $defined_commands --error {|cmd| $"The command ($cmd | ft input) found in ($config_toml | ft) has no definition in ($depman_config.commands_script | ft)." }
		}
		| with {|commands|
			$defined_commands
			| wrap name 
			| insert value {{}}
			| transpose -r
			| merge ($commands | transpose -r)
			| transpose name value
		}
		| each {|it|
			err-if ($it.name in [cache retrieve obtain update] ) {
				title: "Command uses reserved name"
				message: $"One of the commands you defined in ($depman_config.commands_script | ft file) uses reserved name ($it.name | ft cmd)."
				hint: "Rename the command."
			}
			err-if ($it.name | parse -r '([^\w-])' | is-not-empty ) {
				title: $"Invalid command name"
				message: $"The command found in ($depman_config.commands_script | ft) contains invalid characters in its name: ($it.name | ft input)"
				hint: 'The command name can only contain word characters (\w) and dashes.'
			}
			$it.value
			| check-type record -m {|value, value_type| $"Invalid value for key "commands.($it.name)" in ($config_toml | ft). Type of the value must be record. Found value of type ($value_type | ft type):\n($value)" }
			| run {
				columns
				| all-in  ['fresh-start' 'out-dir' ] --error {|key, valid_keys| $"Unrecognized key ($key | ft input) under [commands] in file ($config_toml | ft). Valid keys are ($valid_keys | recount --and)." } 
			}
			| defaults {
				fresh-start: true,
				out-dir: null
			}
			| run {|value|
				$value.fresh-start
				| check-type bool -m {|value, value_type| $"The value given for key ($'commands.($it.name).fresh-start' | ft key) in ($config_toml | ft) has a type of ($value_type | ft type): \n($value) \n\nType of the value must be boolean."}
				$value.out-dir
				| do-if ($in != null) {0
					check-type string -m {|value, value_type| $"The value given for key ($'commands.($it.name).out-dir' | ft key) in ($config_toml | ft) has a type of ($value_type | ft type): ($value) \n\nType of the value must be ('string' | ft type)."}
				}
			}
			| {name: $it.name, ...$in}
		}
	}
	
	def parse_lockfile []: nothing -> any { ignore
		do-if ($depman_config.lockfile | path exists) {
			open $depman_config.lockfile
			| from json
			| check-type 'table<src_hash: string, content_hash: string>' --structured -m {
				$"Invalid lockfile at ($depman_config.lockfile). Did you modify it by hand? \nPlease either remove it to regenerate or restore it to its previous state."
			}
		}
	}

	def parse_depman_config [config: record, config_defaults: record]: [nothing -> 
		record<
			out-dir: path,
			cache-dir: path,
			dependencies_file: path,
			lockfile: path,
			commands_script: path,
			default-command: string
		>
	] { ignore
		$config.depman?
		| default {}
		| check-type 'record' -m {$'Invalid value for key "depman" in "($config_toml)". Type of the value must be record.'}
		| run {
			columns
			| all-in ['out-dir', 'cache-dir', 'default-command'] --error {|key, valid_keys| $"Unrecognized key ($key | ft input) under ('[depman]' | ft key) in file ($config_toml | ft). Valid keys are one of ($valid_keys | recount)." }
		}
		| defaults $config_defaults
	}

	def parse_dependencies []: [ nothing ->
        table<
            name: string,
            sources: table<
                depset: string
                value: record<
                    type: string,
                    description: any, # string | record
                    depman-cmd: string
                >
            >
        >] { ignore
		do-if ($depman_config.dependencies_file | path exists) {
			open-toml $depman_config.dependencies_file
			| default {}
			| (transpose name sources)
			| update sources {|dep|
				let alt_depsets: list<string> = (
					$dep.sources
					| columns
					| filter {|key| $key not-in [http git path rsync cmd depman-cmd]}
				)
				let alt_depset_sources = (
					if ($alt_depsets | is-not-empty) { 
						$dep.sources | select ...$alt_depsets
					} else {
						{}
					}
				)
				let def_source = (
					$dep.sources 
					| reject ...$alt_depsets
					| err-if ($in | is-empty) $'You did not specify a default dependency source for dependency "($dep.name)".'
				)
				{ 
					...{default: $def_source},
					...$alt_depset_sources
				}
				| transpose depset value
				| update value {|source|
					let key_loc_str: string = (
						$' for dependency ($dep.name | ft dep)'
						| do-if ($source.depset != default) { 
							$' in depset ($source.depset | ft depset)' + $in
						}
					)

					$source.value
					| filter-one $'There are multiple sources($key_loc_str).' (unexpected-error "parse_dependencies: No sources for $source.value.")
					| check-type 'record' --err-msg {|value, value_type|
						$"The value specified for depset (($source.depset) | ft depset) for dependency ($dep.name | ft dep) is invalid: \n($value) \n\nA dependency set must be a record with keys specifying a source for the dependency."}
					| reject -i depman-cmd
					| transpose type description -d
					| insert depman-cmd $source.value.depman-cmd?
					| run {|source_value|
						match $source_value.type {
							'git' => { 
								let repo = $source_value.description
								$repo.url?
								| check-type 'string' --err-msg {|value, value_type|
									if $value_type == 'nothing' {
										$'You specified a git repository source($key_loc_str) but did not specify a remote url.'
									} else {
										$"The given url value for the git repository source($key_loc_str) has a type of ($value_type | ft type): \n($value) \n\nType of the value must be string."
									}
								}
								[ $repo.commit? $repo.branch? ]
								| filter-one --allow-none { error $'You specified both commit and branch in the repo source($key_loc_str) for dependency "($dep.name)". You can only specify one.' }
							},
							'http' => {
								let http = $source_value.description
								$http.url?
								| check-type 'string' --err-msg {|value, value_type|
									if $value_type == 'nothing' {
										$'You specified a http source($key_loc_str) but did not specify the url.'
									} else {
										$"The given url value for the http source($key_loc_str) has a type of ($value_type | ft type): \n($value) \n\nType of the value must be string."
									}
								}
								$http.redirect-mode?
								| do-if ($in != null) {
									check-type 'string' --err-msg {|value, value_type| $"The given redirect-mode value for the http source($key_loc_str) has a type of ($value_type | ft type): \n($value) \n\nType of the value must be string."}
									| err-if ($in not-in ['follow' 'error']) $"The given redirect-mode value for the http source($key_loc_str) is invalid: \n($http.redirect-mode?) \n\nThe value must be either ('follow' | style attr_bold) or ('error' | style attr_bold)."
								}
							},
							'path'|'rsync'|'cmd'|'depman-cmd' => {
								$source_value.description
								| check-type 'string' --err-msg {|value, value_type|
									$"The given value for the ($source_value.type) source($key_loc_str) has a type of ($value_type | ft type): \n($value) \n\nType of the value must be string."
								}
								| do-if ($source_value.type in ['path' 'rsync']) {
									try { path expand --strict | ignore } catch { 
										error --title "Can't find path" $"The given ($source_value.type) source($key_loc_str) can't be expanded: ($source_value.description | ft path)" --hint "Is there an item at the specified path?"
									}
								}
							},
							_ => { error $'Unrecognized source type "($source_value.type)"($key_loc_str) for dependency "($dep.name)".' }
						}
					}
				}
			}
		}
	}

	# Create an unexpected error message.
	def unexpected-error [situation: string]: nothing -> record<message: string, title: string> { ignore
		{ source: $NAME, title: "An unexpected error occurred.", message: $"We're sorry about this. In order for this issue to be fixed as soon as possible, please report it at ($"($GITHUB_URL)/issues" | ansi link | style blue) with the following information: \nCause of error: ($situation) \n($NAME) version: ($VERSION)"}
	}
}

# Initiate Depman in your project.
def 'main init' [
	project_dir?: path   # Path to the project directory. (default: current directory)
]: nothing -> nothing { ignore
	let project_dir: path = $project_dir | default '.'
	let depman_dir = [$project_dir $DEPMAN_DIR] | path join
	err-if ($depman_dir | path exists) $"The directory ($depman_dir | ft) already exists. If you want to re-initialize ($NAME), remove the directory before running ($'($CLI_NAME) init' | ft cmd)."
	mkdir $depman_dir
	let gitignore = [$project_dir '.gitignore'] | path join
	if ($gitignore | path exists) {
		open $gitignore | collect
		| $in + "\n/depman/cache/\n/depman/artifacts/"
		| save -f $gitignore
	}
	if (ls $depman_dir | is-empty) {
'export def build [dirs] {
	# Write your build script here.

}
'
		| save -f ([$depman_dir 'commands.nu'] | path join)
	}
}
