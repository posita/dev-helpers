<!---
  Copyright and other protections apply. Please see the accompanying LICENSE file for
  rights and restrictions governing use of this software. All rights not expressly
  waived or licensed are reserved. If that file is missing or appears to be modified
  from its original, then please contact the author before viewing or using this
  software in any capacity.

  !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
  !!!!!!!!!!!!!!! IMPORTANT: READ THIS BEFORE EDITING! !!!!!!!!!!!!!!!
  !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
  Please keep each sentence on its own unwrapped line.
  It looks like crap in a text editor, but it has no effect on rendering, and it allows much more useful diffs.
  Thank you!
-->

The following assumes you are working from the repository root and have a development environment similar to one created by ``pip install install --editable '.[dev]' && python -m pre_commit install``.

* [ ] Update docs and commit
  * Solidify current release start section for next release in [release notes](../docs/notes.md)
  * If necessary, update copyright in [``LICENSE``](../LICENSE) and [``mkdocs.yml``](../mkdocs.yml)

* [ ] ``git clean -Xdf [-n] [...]``

* [ ] ``./helpers/draft-release.sh X Y Z``
  * Performs in-place version search/replace
  * Creates branch ``X.Y.Z-release``
  * Runs ``tox``
  * Tags it as ``vX.Y.Z``
  * Creates and checks distribution files in ``./dist``
  * Updates ``gh-pages``
  * See [``./helpers/draft-release.sh``](draft-release.sh) for details

* [ ] ``git tag --force --sign vX.Y.X && git tag --force latest`` and summarize [release notes](../docs/notes.md)

* [ ] ``./.tox/check/bin/mike serve`` and spot check docs (some images with external references might be missing)

* [ ] ``git push [--force] origin latest vX.Y.Z gh-pages``

* [ ] ``./.tox/check/bin/twine upload [--repository testpypi] [--username __token__] --sign dist/*-X.Y.Z[-.]*``
  * See [Using TestPyPI with pip](https://packaging.python.org/guides/using-testpypi/#using-testpypi-with-pip)
  * Optionally, try to install from test.pypi.org: ``pip install --index-url 'https://test.pypi.org/simple' --extra-index-url 'https://pypi.org/simple' numerary``

* [ ] ``git checkout master``

* [ ] ``git branch --delete [--force] X.Y.Z-release gh-pages``
