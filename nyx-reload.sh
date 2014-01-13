#!/usr/bin/env sh
rm nyx-1.*
echo
gem build nyx.gemspec
echo
gem install nyx-1.4.1.gem