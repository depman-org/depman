# Build depman
export def build [dependency_dirs, source_dir, out_dir] {
    # Bundle the nuitron library with the source
    let nuitron_text = open ($dependency_dirs.nuitron | path join 'mod.nu')
    open ($source_dir | path join 'src' 'depman.nu')
    | str replace 'use  ../deps/nuitron *' ($"\n($nuitron_text)\n")
    | save depman
    chmod +x depman
}

# Prepare for development
export def 'prepare-dev' [dependency_dirs, source_dir, out_dir] {
    cd $source_dir
    mkdir deps
    cp ($dependency_dirs.nuitron | path join mod.nu) ('deps' | path join 'nuitron')
}

# Test that the depman in development can build a previous version of depman and the build result works.
export def test [dependency_dirs, source_dir, out_dir] {
    cd $source_dir
    depman build
    let depman_fresh: path = ([$source_dir 'depman' 'artifacts' 'build' 'depman'] | path join)
    cd $dependency_dirs.depman-v001
    run-external $depman_fresh build
    let depman_v001: path = ([$dependency_dirs.depman-v001 'depman' 'artifacts' 'build' 'depman'] | path join)
    print ""
    run-external $depman_v001 '--version'
}