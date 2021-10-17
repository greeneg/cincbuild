#!/usr/bin/env bash

# Heavily based off the DEB-chef-cinc.sh package. Modified to test environment better for
# base assumptions and prep for use in a full automated build based on current releases
# for upstream Chef.

# we only support Raspbian builds at this time. Will be expanded to work with Debian and
# similar later
. /etc/os-release
if [[ "$ID" -ne 'raspbian' ]]; then echo "This script only runs on Raspbian! Exiting" && exit 1; fi

# One major assumption is that we're using the omnibus user. Test for it
if [[ "$(id -u -n)" -ne 'omnibus' ]]; then echo "This script needs to be run under the 'omnibus' user! Exiting" && exit 1; fi

# We need this fed in to work
if [ -z "$VERSION" ]; then echo "\$VERSION is unset! Exiting"; exit 1; fi

# xtrace, nounset, exit on failures
set -x
set -e
set -u
set -o pipefail

date
echo "PREPPING ENVIRONMENT"

# build environment cleanup
CINC_CLIENT_SERVICE=0
if systemctl list-units --type service | grep -v UNIT | head -n -7 | grep cinc-client; then
  CINC_CLIENT_SERVICE=1
fi
CINC_CLIENT_TIMER=0
if systemctl list-units --type timer | grep -v UNIT | head -n -7 | grep cinc-client; then
  CINC_CLIENT_TIMER=1
fi

if [[ "$CINC_CLIENT_SERVICE" == 1 ]]; then
  sudo systemctl stop cinc-client
fi
if [[ "$CINC_CLIENT_TIMER" == 1 ]]; then
  sudo systemctl stop cinc-client.timer
fi

CINC_PKG=0
if dpkg-query -s cinc >/dev/null 2>&1; then
  CINC_PKG=1
fi
if [[ "$CINC_PKG" == 1 ]]; then
  sudo apt remove cinc -y
fi

echo "PREP WORK COMPLETED!"

# Cinc $VERSION
cd
echo "==============================================================================="
echo " PREPPING FOR BUILD: cinc, $VERSION"
echo "==============================================================================="
rm -rfv $HOME/cinc-full-$VERSION $HOME/cinc-full-$VERSION.tar.xz
sudo rm -rfv /opt/cinc
sudo install -v -d -m 755 -o omnibus -g omnibus /opt/cinc
echo "==============================================================================="
echo " DOWNLOADING SOURCES: cinc, $VERSION"
echo "==============================================================================="
curl --progress-bar http://downloads.cinc.sh/source/stable/cinc/cinc-full-$VERSION.tar.xz --output cinc-full-$VERSION.tar.xz
echo "==============================================================================="
echo " UNPACKING SOURCES: cinc, $VERSION"
echo "==============================================================================="
tar -xvJf cinc-full-$VERSION.tar.xz
cd cinc-full-$VERSION/cinc-$VERSION/omnibus/
exit 0

bundle lock --update=chef
bundle config set without 'development docs debug'
bundle install --path=.bundle
bundle exec omnibus build cinc -l internal
cp ~/cinc-full-$VERSION/cinc-$VERSION/omnibus/pkg/cinc*deb ~/
cp ~/cinc-full-$VERSION/cinc-$VERSION/omnibus/pkg/cinc*deb /tmp/
sudo cp ~/cinc-full-$VERSION/cinc-$VERSION/omnibus/pkg/cinc*deb /root/

chmod 644 /tmp/*deb

echo "$VERSION Complete!"
date
