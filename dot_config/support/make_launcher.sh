#!/bin/bash

APP_DIR=$1
APP_SCRIPT_NAME="$(ls "${APP_DIR}/Contents/MacOS/")"
APP_FILE_NAME="$(basename "${APP_DIR}")"

CHANNEL_DIR="$(dirname "$(dirname "$1")")"
CHANNEL_NAME="$(basename "$CHANNEL_DIR")"
TOOLBOX_APP_NAME="$(basename "$(dirname "$CHANNEL_DIR")")"

TOOLBOX_DIR=${APP_DIR%/apps/*}
LAUNCHERS_DIR="${TOOLBOX_DIR}/launchers"
if [ ! -d "${LAUNCHERS_DIR}" ];then
  echo Creating launcher directory: ${LAUNCHERS_DIR}
  mkdir -p "${LAUNCHERS_DIR}"
fi

LAUNCHER_PATH="${LAUNCHERS_DIR}/${APP_FILE_NAME}"
if [ -d "${LAUNCHER_PATH}" ];then
  echo Launcher already exists at path ${LAUNCHER_PATH}
  echo exiting.
  exit 1
fi

# Create the launcher directory structure
echo Creating launcher at path: ${LAUNCHER_PATH}
mkdir -p "$LAUNCHER_PATH/Contents/MacOS"

# Link the existing
ln -s -f "$APP_DIR/Contents/Info.plist" "$LAUNCHER_PATH/Contents/Info.plist"
ln -s -f "$APP_DIR/Contents/Resources" "$LAUNCHER_PATH/Contents/Resources"

LAUNCHER_SCRIPT_PATH="$LAUNCHER_PATH/Contents/MacOS/$APP_SCRIPT_NAME"
function write() {
  echo "$1" >> "$LAUNCHER_SCRIPT_PATH"
}

write '#!/bin/sh'
write ''
write 'DIR="$(dirname "$0")"'
write 'BASE_DIR="$DIR/../../../../apps/'"$TOOLBOX_APP_NAME"'/'"$CHANNEL_NAME"'"'
write 'SUFFIX="Contents/MacOS/'"$APP_SCRIPT_NAME"'"'
write ''
write 'release_dirname=$(ls "$BASE_DIR" | sort -r | head -n 1)'
write 'release_dir="$BASE_DIR/$release_dirname"'
write ''
write 'app_dir="$release_dir/'"$APP_FILE_NAME"'"'
write 'app_path="$app_dir/$SUFFIX"'
write ''
write '# Make sure the info.plist and resources are current.'
write 'ln -s -f "$app_dir/Contents/Info.plist" "$DIR/../Info.plist"'
write 'ln -s -f "$app_dir/Contents/Resources" "$DIR/../Resources"'
write ''
write '"$app_path"'

echo Making launcher script executable...
chmod +x "$LAUNCHER_SCRIPT_PATH"

echo Successfully created launcher for $APP_FILE_NAME in channel $CHANNEL_NAME
open "$LAUNCHERS_DIR"
