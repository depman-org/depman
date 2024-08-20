#!/usr/bin/env nu

const NAME = Depman
const VERSION = '0.1.0'
const NU_VERSION = '0.96.1'
const depman_toml = "depman.toml"

let nu_version = try { (version).version }
if nu_version != $NU_VERSION {
    print $"Your Nushell version is not compatible with ($NAME). Required version is ($NU_VERSION).\nYou can download different versions of Nushell here: https://github.com/nushell/nushell/releases"
    exit
}

if ($depman_toml | path exists) {
    let deps = open $depman_toml | get toml
    print $deps
}