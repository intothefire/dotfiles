#!/usr/bin/env zsh

source ~/.zshrc

PLIST_LOC=~/Library/Application\ Support/com.fournova.Tower3

if [ ! -d $PLIST_LOC ]; then
  PLIST_LOC="/Users/cnorman/Dropbox/Mackup/Library/Application Support/com.fournova.Tower3"
fi

touch "$PLIST_LOC/environment.plist"

cat > "$PLIST_LOC/environment.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>PATH</key>
	<string>${PATH}</string>
</dict>
</plist>
EOF