#!/usr/bin/env zsh

NVM_DIR=~/.nvm
RVM_DIR=~/.rvm

curl -fsSL -o install.sh https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh && /bin/bash install.sh && rm -rf install.sh

if ! [ -d "$RVM_DIR" ]; then \curl -L https://get.rvm.io | bash -s stable --ruby; fi
source ${RVM_DIR}/scripts/rvm
rvm install ruby-2.7.3
rvm install ruby-2.7.4
rvm --default use 2.7.4

mkdir -p "$NVM_DIR"
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | /bin/zsh
. ${NVM_DIR}/nvm.sh && nvm install --lts

npm install -g i18next-parser