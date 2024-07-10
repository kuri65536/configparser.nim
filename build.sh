#! /bin/bash
function build() {
    nimble build
}


function tests1() {
    nimble test
}


function tests2() {
    testament pattern 'tests/test*.nim'
    testament html
    mkdir -p html
    mv -f testresults.html html
}


function doc() {
    nim doc --outdir:html src/configparser.nim
    cd html; ln -sf configparser.html index.html
}


case "x$1" in
xdoc)
    doc
    ;;
xtests)
    tests1
    ;;
*)
    build
    ;;
esac
