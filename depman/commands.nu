use './cache/nuitron_ed961c8d9425e89eea2f78131b0b3577' *

# Build Depman
export def build [dirs] {
    open ([$dirs.source src depman.nu] | path join)
    | bundle-file $dirs
    | str replace "use '../depman/cache/nuitron_ed961c8d9425e89eea2f78131b0b3577' *" ''
    | save depman
    chmod +x depman
}

# Build and run Depman
export def run [dirs, args?] {
    build $dirs
    let depman_path: path = ([$dirs.out 'depman'] | path join)
    run-external $depman_path ...$args
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
    with {|script|
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
                | do-if ($match.flag_base64 | is-not-empty) {
                    encode new-base64
                    | $"'($in)'"
                }
            )
        }
    }
}