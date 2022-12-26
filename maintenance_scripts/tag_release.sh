#!/usr/bin/env bash
# shellcheck disable=SC2016

# Licensed under GPLv3, see https://www.gnu.org/licenses/

set -euo pipefail
IFS=$'\n\t'
aur_repo_dir=~/build/pikaur
aur_dev_repo_dir=~/build/pikaur-git
src_repo_dir=$(readlink -e "$(dirname "${0}")"/..)

new_version=$1

if [[ $(git status --porcelain 2>/dev/null| grep -c "^ [MD]" || true) -gt 0 ]] ; then
	echo
	echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
	echo "!!    You have uncommitted changes:    !!"
	echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
	echo
	git status

	echo
	echo "?????????????????????????????????????????"
	echo "??    Do you want to proceed? [y/N]    ??"
	echo "?????????????????????????????????????????"
	echo -n "> "
	read -r answer
	echo
	if [[ "${answer}" != "y" ]] ; then
		exit 1
	fi
	answer=
fi

./maintenance_scripts/show_recent_history.sh -c || true

echo
echo "*******************************"
echo "**    Updating version...    **"
echo "*******************************"
echo

sed -i -e "s/pkgver=.*/pkgver=${new_version}/g" PKGBUILD
sed -i -e "s/pkgrel=.*/pkgrel=1/g" PKGBUILD
sed -i -e 's/VERSION.*=.*/VERSION: Final = "${new_version}-dev"/g' pikaur/config.py
sed -i -e "s/    version='.*',/    version='${new_version}',/g" setup.py

echo
echo "??????????????????????????????????????????????????????????????????????"
echo "??    Confirm pushing ${new_version} to Pikaur GitHub repo? [y/N]   ??"
echo "??????????????????????????????????????????????????????????????????????"
echo -n "> "
read -r answer
echo
if [[ "${answer}" = "y" ]] ; then
	git commit -am "chore: bump version to ${new_version}" || true
	git tag -a "${new_version}"
	git push origin HEAD
	git push origin "${new_version}"
fi
answer=


echo
echo "***************************************"
echo "**    Updating AUR dev PKGBUILD...   **"
echo "***************************************"
echo
./maintenance_scripts/changelog.sh > "${aur_dev_repo_dir}"/CHANGELOG
cp PKGBUILD "${aur_dev_repo_dir}"/PKGBUILD
# shellcheck disable=SC2164
cd "${aur_dev_repo_dir}"
makepkg --printsrcinfo > .SRCINFO
echo
echo "??????????????????????????????????????????????????"
echo "??    Confirm push to AUR dev package? [y/N]    ??"
echo "??????????????????????????????????????????????????"
echo -n "> "
read -r answer
echo
if [[ "${answer}" = "y" ]] ; then
	git add PKGBUILD .SRCINFO CHANGELOG
	git commit -m "update to ${new_version}"
	git push origin HEAD
fi
answer=


echo
echo "*******************************************"
echo "**    Updating AUR release PKGBUILD...   **"
echo "*******************************************"
echo
cd "${src_repo_dir}"
./maintenance_scripts/changelog.sh > "${aur_repo_dir}"/CHANGELOG
sed \
	-e 's|pkgname=pikaur-git|pkgname=pikaur|' \
	-e 's|"$pkgname::git+https://github.com/actionless/pikaur.git#branch=master"|"$pkgname-$pkgver.tar.gz"::https://github.com/actionless/pikaur/archive/"$pkgver".tar.gz|' \
	-e "s|conflicts=('pikaur')|conflicts=('pikaur-git')|" \
	-e 's|cd "${srcdir}/${pkgname}"|cd "${srcdir}/${pkgname}-${pkgver}"|' \
	-e '/pkgver() {/,+5 d' \
	PKGBUILD > "${aur_repo_dir}"/PKGBUILD
# shellcheck disable=SC2164
cd "${aur_repo_dir}"
updpkgsums
makepkg --printsrcinfo > .SRCINFO

echo
echo "??????????????????????????????????????????????????????"
echo "??    Confirm push to AUR release package? [y/N]    ??"
echo "??????????????????????????????????????????????????????"
echo -n "> "
read -r answer
echo
if [[ "${answer}" = "y" ]] ; then
	git add PKGBUILD .SRCINFO CHANGELOG
	git commit -m "update to ${new_version}"
	git push origin HEAD
fi
answer=


echo
echo "??????????????????????????????????????????????????????"
echo "??    Confirm push to PyPI release package? [y/N]   ??"
echo "??????????????????????????????????????????????????????"
echo -n "> "
read -r answer
echo
if [[ "${answer}" = "y" ]] ; then
	cd "${src_repo_dir}"
	rm -fr ./dist
	env PYPY_BUILD=1 python setup.py sdist
	twine check ./dist/*
	twine upload ./dist/*
fi
answer=


echo
echo '$$$$$$$$$$$$$$$$$$$$$$$$$'
echo '$$    Full Success!    $$'
echo '$$$$$$$$$$$$$$$$$$$$$$$$$'

exit 0
