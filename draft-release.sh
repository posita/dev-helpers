#!/usr/bin/env bash
# ======================================================================================
# Copyright and other protections apply. Please see the accompanying LICENSE file for
# rights and restrictions governing use of this software. All rights not expressly
# waived or licensed are reserved. If that file is missing or appears to be modified
# from its original, then please contact the author before viewing or using this
# software in any capacity.
# ======================================================================================

set -e
_MY_DIR="$( cd "$( dirname "${0}" )" && pwd )"
[ "${_MY_DIR}/draft-release.sh" -ef "${0}" ]

function _yes_no () {
    printf "${1}${1:+ }[Y/n] "
    local sh=$( ps -o comm -p "${$}" | awk 'NR == 2' )

    while true ; do
        if [ "${sh%[/-]zsh}" != "${sh}" ] ; then
            read -k 1 -s  # zsh
        else
            read -n 1 -s  # everywhere else
        fi

        case "${REPLY}" in
            Y|y|$'\n'|'')
                REPLY=y
                echo 'yes'
                break
                ;;
            N|n)
                REPLY=n
                echo 'no'
                break
                ;;
        esac

        printf '\n[Y/n] '
    done
}

if [ "${#}" -ne 0 ] ; then
    echo 1>&2 "usage: $( basename "${0}" )"

    exit 1
fi

for _repo_dir_candidate in "${_MY_DIR}${_MY_DIR:+/}.." "${PWD}" ; do
    if [ -d "${_repo_dir_candidate}/.git" ] ; then
        _yes_no "Use \"${_repo_dir_candidate}\" as the repository directory?"

        if [ "${REPLY}" = y ] ; then
            _REPO_DIR="$( cd "${_repo_dir_candidate}" && pwd )"
            break
        fi
    fi
done

if [ -z "${_REPO_DIR}" ] ; then
    echo 1>&2 "$( basename "${0}" ): unable to find repository directory"

    exit 1
fi

set -x
cd "${_REPO_DIR}"
git update-index -q --refresh
VERSION="$( python -m setuptools_scm | perl -pe 's/^Guessed Version ([^ ]+).*$/\1/' )"
set +x

if ! echo "${VERSION}" | grep -Eq '^\d+\.\d+\.\d+$' ; then
    _yes_no "Really use \"${VERSION}\" as version?"

    if [ "${REPLY}" != y ] ; then
        exit 1
    fi
fi

set -x
_GET_PKG_PY="$( cat <<EOF
import configparser, sys
config = configparser.ConfigParser()
config.read_file(open(sys.argv[1]))
name = config.get("metadata", "name")
print(name)
EOF
)"

_GET_PROJECT_PY="$( cat <<EOF
import configparser, pathlib, sys, urllib.parse
config = configparser.ConfigParser()
config.read_file(open(sys.argv[1]))
url = urllib.parse.urlparse(config.get("metadata", "url"))
project = pathlib.PurePath(url.path).parts[1]
print(project)
EOF
)"

PKG="$( python -c "${_GET_PKG_PY}" "${_REPO_DIR}/setup.cfg" )"
PROJECT="$( python -c "${_GET_PROJECT_PY}" "${_REPO_DIR}/setup.cfg" )"
VERSION="$( echo "${VERSION}" | perl -pe 's/\+.*$//' )"
VERS="$( echo "${VERSION}" | perl -pe 's/^(\d+\.\d+)\.\d+(\.[^.]+)*$/\1/' )"
VERS_PATCH="$( echo "${VERSION}" | perl -pe 's/^(\d+\.\d+\.\d+)(\.[^.]+)*$/\1/' )"
TAG="v${VERS_PATCH}"

if [ -f README.md ] ; then
    perl -p -i -e "
  s{\\.github\\.io/${PROJECT}/\\d+\\.\\d+\\/([^) \"]*)} {\\.github\\.io/${PROJECT}/${VERS}/\\1}g ;
  s{/${PROJECT}/([^/]+/)*v\\d+\\.\\d+\\.\\d+([/?])} {/${PROJECT}/\\1${TAG}\\2}g ;
  s{//pypi\\.org/([^/]+/)?${PKG}/\\d+\\.\\d+\\.\\d+/} {//pypi.org/\\1${PKG}/${VERS_PATCH}/}g ;
  s{/pypi/([^/]+/)?${PKG}/\\d+\\.\\d+\\.\\d+\\.svg\\)} {/pypi/\\1${PKG}/${VERS_PATCH}.svg)}g ;
" README.md
fi

if [ -f mkdocs.yml ] ; then
    perl -p -i -e "
  s{__vers_str__\\b\\s*:\\s*\\d+\\.\\d+\\.\\d+\\b} {__vers_str__: ${VERS_PATCH}}g ;
" mkdocs.yml
fi

git update-index -q --refresh

if ! git diff-index --quiet HEAD -- ; then
    git status
    echo 1>&2 "$( basename "${0}" ): changes detected after substitutions"

    exit 1
fi

set +x
problem_areas="$(
    grep -En "^#+\\s+${MAJOR}\\.${MINOR}\\.${PATCH}([^[:alnum:]]|$)" /dev/null mkdocs.yml docs/notes.md || [ "${?}" -eq 1 ]
)"

if [ -n "${problem_areas}" ] ; then
    echo '- - - - POTENTIAL PROBLEM AREAS - - - -'
    echo "${problem_areas}"
    echo '- - - - - - - - - - - - - - - - - - - -'

    sh=$( ps -o comm -p "${$}" | awk 'NR == 2' )
    _yes_no "Potential problem areas detected. Continue anyway?"

    if [ "${REPLY}" = n ] ; then
        git status

        exit 1
    fi
fi

set -x
tox
python -c 'from setuptools import setup ; setup()' sdist
(
    . "${_REPO_DIR}/.tox/check/bin/activate"
    twine check "dist/${PKG}-${VERSION}"[-.]*
    mike deploy --rebase --update-aliases "${VERS}" latest
)
git tag --force --message "$( cat <<EOF
Release ${TAG}.

<TODO: Copy ${VERS_PATCH} [release notes](docs/notes.md) here. Hope you were keeping track!>
EOF
)" "${TAG}"
