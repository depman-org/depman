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
    ensure-cmd depman
    let create_parse_error = $args.0? == 'parse-error'
    rm -rf $dirs.cache
    depman prep -q
    depman build -q
    let commands_path = [$dirs.source depman commands.nu] | path join
    let new_depman = [$dirs.source depman artifacts 
    
    build depman] | path join | path expand --strict
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
            run-external $new_depman 'i-am-not-a-command-this-must-error' 
        } catch {|err|
            open $commands_path | collect | str substring 3.. | save -f $commands_path
            $err.raw
        }
    } else {
        run-external $new_depman ...$args
    }
}

# Test Depman
# Check that the working copy can build itself and the build output works
export def test [dirs] {
    build-run $dirs [--quiet build]
    let new_depman = [ $dirs.source depman artifacts build depman ] | path join
    run-external $new_depman '--version'
}

export def release [dirs] {
    let head_is_on_main = try { (git symbolic-ref --short HEAD) == main} catch { false }
    if not $head_is_on_main {
        error make { msg: 'Releases are made from the main branch, but the current git HEAD is not attached to the main branch.'  }
    }
    print $"
A new Github release will be created from the current git HEAD pointing to this commit:\n
(ansi rb)(git log -1 --pretty=%B)(ansi reset)
"
    test $dirs
    build $dirs
    
    let cliff_dir = [$dirs.source .github ci git-cliff] | path join
    alias chlog = git-cliff --config ($cliff_dir | path join 'changelog.toml') --repository $dirs.source
    alias relnote = git-cliff --config ($cliff_dir | path join 'release-notes.toml') --repository $dirs.source
    chlog --bumped-version --output new_tag.txt e>| ignore
    let new_tag = open new_tag.txt
    rm new_tag.txt

    let new_depman = [ $dirs.source depman artifacts build depman ] | path join
    cp $new_depman .
    let file_name = $"depman-($new_tag).zip"
    ^zip $file_name ./depman

    relnote --unreleased --bump --strip header --output release-notes.txt e>| ignore
    let release_notes = open release-notes.txt
    rm release-notes.txt

    let changelog_path = ([$dirs.source CHANGELOG.md] | path join)
    chlog --use-branch-tags --output $changelog_path e>| ignore
    git add $changelog_path
    git commit -m $"chore\(release\): prepare for release ($new_tag)"
    git tag $new_tag
    git push origin --tags

    let response = (
        http post https://api.github.com/repos/depman-org/depman/releases
            --content-type application/json
            --headers [
                Accept application/vnd.github+json
                Authorization $'Bearer ($env.GITHUB_TOKEN)'
                X-GitHub-Api-Version '2022-11-28'
            ]
            { 
                tag_name: $new_tag, 
                name: $"Depman ($new_tag)", 
                body: $release_notes
            }
    )
    
    let url = $response.upload_url | str replace -r '\{\?name,label\}' $'?name=($file_name)'

    (http post $url
        --content-type application/octet-stream
        --headers [
            "Accept" "application/vnd.github+json"
            "Authorization" $"Bearer ($env.GITHUB_TOKEN)"
            "X-GitHub-Api-Version" "2022-11-28"
        ]
        (open -r $file_name)
    )
    | ignore
}

# Error if an external command is not installed.
def ensure-cmd [cmd_name] {
    if (which $cmd_name | is-empty) {
        error make --unspanned { msg: 'You need to have Depman installed on your system to develop Depman.'}
    }
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