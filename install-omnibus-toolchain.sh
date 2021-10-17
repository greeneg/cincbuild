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

# xtrace, nounset, exit on failures
set -x
set -e
set -u
set -o pipefail

date
echo "PREPPING ENVIRONMENT"

# package checks
OMNIBUS_TOOLCHAIN_PKG=0
if dpkg-query -s omnibus-toolchain >/dev/null 2>&1; then
  OMNIBUS_TOOLCHAIN_PKG=1
fi

if [[ "$OMNIBUS_TOOLCHAIN_PKG" == 1 ]]; then
  sudo apt remove omnibus-toolchain -y
fi

echo "PREP WORK COMPLETED!"

# function to install rbenv and the ruby-build plugin
function install_rbenv () {
  echo "==============================================================================="
  echo " INSTALLING: rbenv "
  echo "==============================================================================="
  git clone https://github.com/rbenv/rbenv.git $HOME/.rbenv
  cd $HOME/.rbenv && src/configure && make -C src
  mkdir -pv plugins
  git clone https://github.com/rbenv/ruby-build.git "$(rbenv root)"/plugins/ruby-build
}

function build_ruby () {
  local ruby_ver=${$1:-'2.7.4'}

  echo "==============================================================================="
  echo " BUILDING: Ruby $ruby_ver "
  echo "==============================================================================="
  rbenv install -v $ruby_ver
  rbenv global $ruby_ver
}

# Ruby 2.7.4
cd
rm -rfv ~/.bundle
rm -rfv ~/.gem
if [[ -d $HOME/.rbenv ]]; then
  RUBYVERSION="$(rbenv version | awk '{ print $1 }')"
  if [[ $RUBYVERSION =~ 2.7.4 ]]; then
    echo "Using existing Ruby 2.7.4 provided by rbenv"
  else
    build_ruby "2.7.4"
    eval "$(rbenv init -)"
  fi
else
  # first install rbenv
  install_rbenv
  # now install the version we need
  build_ruby "2.7.4"
  eval "$(rbenv init -)"
fi

# Omnibus-Toolchain
cd
# create our packages directory
echo "==============================================================================="
echo " PREPPING FOR BUILD: omnibus-toolchain"
echo "==============================================================================="
if [ ! -d $HOME/pkgs ]; then
  install -v -d -m 755 -o omnibus -g omnibus $HOME/pkgs
fi
if [ -d $HOME/omnibus-toolchain ]; then
  rm -rfv $HOME/omnibus-toolchain
fi
if [ -d /opt/omnibus-toolchain ]; then
  sudo rm -rfv /opt/omnibus-toolchain
  sudo install -v -d -m 755 -o omnibus -g omnibus /opt/omnibus-toolchain
fi
if [ -d /var/cache/omnibus ]; then
  sudo rm -rfv /var/cache/omnibus
  sudo install -v -d -m 755 -o omnibus -g omnibus /var/cache/omnibus
fi
echo "==============================================================================="
echo " BUILDING: omnibus-toolchain"
echo "==============================================================================="
git clone https://github.com/chef/omnibus-toolchain.git
cd "$HOME/omnibus-toolchain"
bundle config set without 'development docs debug'
echo "==============================================================================="
echo " INSTALLING: omnibus-toolchain"
echo "==============================================================================="
bundle install --path=.bundle
echo "==============================================================================="
echo " BUILDING BUNDLED TOOLCHAIN DEBIAN PACKAGE"
echo "==============================================================================="
bundle exec omnibus build omnibus-toolchain -l internal
install -v -m 644 -o omnibus -g omnibus $HOME/omnibus-toolchain/pkg/omnibus-toolchain*deb $HOME/pkgs/
# running cleanup from potentially other failed installs
if [ -d /opt/omnibus-toolchain ]; then
  sudo rm -rfv /opt/omnibus-toolchain
fi
sudo dpkg --debug=1 -i $HOME/pkgs/omnibus-toolchain*deb
sudo chown omnibus:omnibus -R /opt/omnibus-toolchain
export PATH="/opt/omnibus-toolchain/bin:$PATH"
echo "==============================================================================="
echo " TOOLCHAIN INSTALLED!"
echo "==============================================================================="

date
