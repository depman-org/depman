# Build Depman
export def build [dirs] {
    open ([$dirs.source src depman.nu] | path join)
    | bundle-file $dirs
    | str replace 'use ../depman/cache/nuitron *' ''
    | save depman
    chmod +x depman
}

# Build Depman with system Depman and run it with the given arguments
export def build-run [dirs, args?] {
    let create_parse_error = $args.0? == 'parse-error'
    rm -rf $dirs.cache
    depman prep -q
    depman build -q
    let commands_path = [$dirs.cache .. commands.nu] | path join
    let depman_path = [$dirs.cache .. artifacts build depman] | path join | path expand --strict
    # Unquote arguments so that flags may be passed to depman.
    let args = (
        $args
        | each {|str|    
            if (['"' "'" '`'] | any {|qt| ($str starts-with $qt) and ($str ends-with $qt)}) {
                $str | str substring 1..(-2)
            } else { $in }
        }
    )
    if $create_parse_error {
        open $commands_path | collect | "{]\n" + $in | save -f $commands_path
        try {
            run-external $depman_path 'i-am-not-a-command-this-must-error' 
        } catch {|err|
            open $commands_path | collect | str substring 3.. | save -f $commands_path
            $err.raw
        }
    } else {
        run-external $depman_path ...$args
    }
}

# Test Depman
# Check that the working copy version can build a previous version of Depman and the build result works.
export def test [dirs] {
    if (which depman | is-empty) {
        error make --unspanned { msg: 'You need to have Depman installed on your system to test Depman.'}
    }
    cd $dirs.source
    depman build
    let depman_fresh: path = ([$dirs.source 'depman' 'artifacts' 'build' 'depman'] | path join)
    cd $dirs.dependencies.depman-v001
    run-external $depman_fresh build
    let depman_v001: path = ([$dirs.dependencies.depman-v001 'depman' 'artifacts' 'build' 'depman'] | path join)
    print ""
    run-external $depman_v001 '--version'
}

# Bundle the necessary files
def bundle-file [dirs]: string -> string {
    do {|script|
        | parse -r r#'(?<command>bundle-file(?: +(?<flag_base64>--base64))? +(?<dep_name>'[^']*'|[^ )\t\r\n;|}]+) +(?<file_path>'[^ ]*'|[^ )\t\r\n;|}]+))'#
        | update cells --columns [dep_name file_path] { str trim -c "'" }
        | reduce --fold $script {|match, acc|
            $acc
            | str replace $match.command (
                $dirs.dependencies
                | get ([$match.dep_name] | into cell-path)
                | path join $match.file_path
                | path expand --strict
                | open $in
                | if ($match.flag_base64 | is-not-empty) {
                    encode new-base64
                    | $"'($in)'"
                } else { $in }
            )
        }
    } $in
}

# Prepare Depman for development
export def prep [dirs] {
    ln -s $dirs.dependencies.nuitron ($dirs.cache | path join 'nuitron')
}

# Testing with various error types

# Create a shell error
export def shell-error [dirs, args?] {
	{ha: hi}
    | get ho
}

# Create a rsync error
export def rsync-error [dirs, args?] {
	rsync 'bogus' 'sheesh'
}

# Create a streaming command error
export def stream-error [dirs, args?] {
	1..10 | each { print $in; sleep 0.15sec}
	nu -c 'exit 14'
}