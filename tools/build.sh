#!/bin/bash

set -e

# set time zone
ln -s /usr/share/zoneinfo/UTC /etc/localtime

# set locale
echo 'en_US.UTF-8 UTF-8' > /etc/locale.gen
locale-gen
echo 'LANG=en_US.UTF-8' > /etc/locale.conf

# wget
pacman -Syu --noconfirm --needed                       \
    wget                                               \
    
# install R dependencies
pacman -Syu --noconfirm --needed                       \
    base                                               \
    base-devel                                         \
    curl                                               \
    icu                                                \
    lapack                                             \
    libtiff                                            \
    libxmu                                             \
    pango                                              \
    pcre2                                              \
    perl                                               \
    unzip                                              \
    which                                              \
    zip                                                \
    blas-openblas                                      \
    gcc-fortran                                        \
    texlive                                            \
    tk                                                 \
    jdk-openjdk

# build R from source

R_VERSION=${1:-${R_VERSION:-"latest"}}

# shellcheck source=/dev/null
source /etc/os-release

# Download R from 0-Cloud CRAN mirror or CRAN
function download_r_src() {
    wget "https://cloud.r-project.org/src/$1" -O "R.tar.gz" ||
        wget "https://cran.r-project.org/src/$1" -O "R.tar.gz"
}

if [ "$R_VERSION" == "devel" ]; then
    download_r_src "base-prerelease/R-devel.tar.gz"
elif [ "$R_VERSION" == "patched" ]; then
    download_r_src "base-prerelease/R-latest.tar.gz"
elif [ "$R_VERSION" == "latest" ]; then
    download_r_src "base/R-latest.tar.gz"
else
    download_r_src "base/R-${R_VERSION%%.*}/R-${R_VERSION}.tar.gz"
fi

tar xzf "R.tar.gz"
cd R-*/

# compile

R_PAPERSIZE=letter \
    R_BATCHSAVE="--no-save --no-restore" \
    R_BROWSER=xdg-open \
    PAGER=/usr/bin/pager \
    PERL=/usr/bin/perl \
    R_UNZIPCMD=/usr/bin/unzip \
    R_ZIPCMD=/usr/bin/zip \
    R_PRINTCMD=/usr/bin/lpr \
    LIBnn=lib \
    AWK=/usr/bin/awk \
    CFLAGS="-g -O2 -fstack-protector-strong -Wformat -Werror=format-security -Wdate-time -D_FORTIFY_SOURCE=2 -g" \
    CXXFLAGS="-g -O2 -fstack-protector-strong -Wformat -Werror=format-security -Wdate-time -D_FORTIFY_SOURCE=2 -g" \
    ./configure --enable-R-shlib \
    --enable-memory-profiling \
    --with-readline \
    --with-blas \
    --with-lapack \
    --with-tcltk \
    --with-recommended-packages

make
make install
make clean

# Add a library directory (for user-installed packages)
groupadd staff
mkdir -p "${R_HOME}/site-library"
chown root:staff "${R_HOME}/site-library"
chmod g+ws "${R_HOME}/site-library"

# Fix library path
echo "R_LIBS=\${R_LIBS-'${R_HOME}/site-library:${R_HOME}/library'}" >>"${R_HOME}/etc/Renviron.site"

# Clean up from R source install
cd ..
rm -rf /tmp/*
rm -rf R-*/
rm -rf "R.tar.gz"

# remove the packages downloaded to image's pacman cache dir.
pacman -Sy --noconfirm pacman-contrib
paccache -r -k0

# Check the R info
echo -e "Check the R info...\n"

R -q -e "sessionInfo()"

echo -e "\nInstall R from source, done!"
