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
if [[ -z "$CINC_VERSION" ]]; then echo "\$CINC_VERSION is unset! Exiting"; exit 1; fi

# nounset, exit on failures
set -e
set -u
set -o pipefail

DEBUG=${DEBUG:-}
if [[ -n "$DEBUG" ]]; then set -x; fi

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

# Cinc $CINC_VERSION
cd
echo "==============================================================================="
echo " PREPPING FOR BUILD: cinc, $CINC_VERSION"
echo "==============================================================================="
# to best allow us to use upstream's releases, don't use the cinc-full build, but rather
# use the git sources of Chef directly
rm -rfv $HOME/cinc-full-$CINC_VERSION $HOME/cinc-full-$CINC_VERSION.tar.xz
sudo rm -rfv /opt/cinc
sudo install -v -d -m 755 -o omnibus -g omnibus /opt/cinc
mkdir -pv $HOME/cinc-full-$CINC_VERSION
echo "==============================================================================="
echo " DOWNLOADING SOURCES: cinc, $CINC_VERSION"
echo "==============================================================================="
cd $HOME/cinc-full-$CINC_VERSION
git clone https://github.com/chef/chef.git $HOME/cinc-full-$CINC_VERSION/cinc-$CINC_VERSION
git clone https://github.com/chef/omnibus-software $HOME/cinc-full-$CINC_VERSION/omnibus-software
exit 0
#curl --progress-bar http://downloads.cinc.sh/source/stable/cinc/cinc-full-$CINC_VERSION.tar.xz --output cinc-full-$CINC_VERSION.tar.xz
echo "==============================================================================="
echo " UNPACKING SOURCES: cinc, $CINC_VERSION"
echo "==============================================================================="
tar -xvJf cinc-full-$CINC_VERSION.tar.xz
cd cinc-full-$CINC_VERSION/cinc-$CINC_VERSION/omnibus/
exit 0

bundle lock --update=chef
bundle config set without 'development docs debug'
bundle install --path=.bundle
bundle exec omnibus build cinc -l internal
cp ~/cinc-full-$CINC_VERSION/cinc-$CINC_VERSION/omnibus/pkg/cinc*deb ~/
cp ~/cinc-full-$CINC_VERSION/cinc-$CINC_VERSION/omnibus/pkg/cinc*deb /tmp/
sudo cp ~/cinc-full-$CINC_VERSION/cinc-$CINC_VERSION/omnibus/pkg/cinc*deb /root/

chmod 644 /tmp/*deb

echo "$CINC_VERSION Complete!"
date
