#!/usr/bin/env bash
# Gera o DMG de instalação do copyMemory (arrastar o app para Aplicativos).
# Não precisa de conta Apple Developer paga.
#
# Uso:
#   ./scripts/create-dmg.sh
#   ./scripts/create-dmg.sh /caminho/para/copyMemory.app
#
# Saída: dist/copyMemory.dmg

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="copyMemory"
VOLUME_NAME="copyMemory"
BACKGROUND="$ROOT/packaging/dmg/background.png"
DIST="$ROOT/dist"
STAGING="$DIST/dmg-staging"
RW_DMG="$DIST/${APP_NAME}-rw.dmg"
FINAL_DMG="$DIST/${APP_NAME}.dmg"

WINDOW_X=200
WINDOW_Y=120
WINDOW_W=600
WINDOW_H=400
ICON_SIZE=128
APP_ICON_X=150
APP_ICON_Y=185
DROP_ICON_X=450
DROP_ICON_Y=185

if [[ ! -f "$BACKGROUND" ]]; then
  echo "Fundo do DMG não encontrado: $BACKGROUND" >&2
  exit 1
fi

if [[ $# -ge 1 ]]; then
  APP="$1"
else
  echo "Compilando Release…"
  xcodebuild \
    -project "$ROOT/copyMemory.xcodeproj" \
    -scheme copyMemory \
    -configuration Release \
    -derivedDataPath "$ROOT/build/DerivedData" \
    -destination "platform=macOS" \
    build
  APP="$ROOT/build/DerivedData/Build/Products/Release/${APP_NAME}.app"
fi

if [[ ! -d "$APP" ]]; then
  echo "App não encontrado: $APP" >&2
  echo "Passe o .app exportado do Organizer: ./scripts/create-dmg.sh /caminho/copyMemory.app" >&2
  exit 1
fi

mkdir -p "$DIST"
rm -f "$FINAL_DMG"

# No GitHub Actions o Finder não aceita o AppleScript de layout.
# O dmgbuild grava fundo, tamanho da janela e posição dos ícones no .DS_Store.
if [[ -n "${CI:-}" ]]; then
  export PATH="${HOME}/.local/bin:${PATH}"
  if ! command -v dmgbuild >/dev/null; then
    echo "dmgbuild não encontrado. No runner: brew install pipx && pipx install dmgbuild" >&2
    exit 1
  fi
  echo "CI: gerando DMG com o layout de instalação…"
  dmgbuild \
    -s "$ROOT/packaging/dmg/settings.py" \
    -D "app=${APP}" \
    -D "background=${BACKGROUND}" \
    "$VOLUME_NAME" \
    "$FINAL_DMG"
  echo
  echo "DMG pronto: $FINAL_DMG"
  exit 0
fi

if [[ -d "/Volumes/${VOLUME_NAME}" ]]; then
  hdiutil detach "/Volumes/${VOLUME_NAME}" -quiet || hdiutil detach "/Volumes/${VOLUME_NAME}" -force
fi

rm -rf "$STAGING" "$RW_DMG"
mkdir -p "$STAGING/.background"

ditto "$APP" "$STAGING/${APP_NAME}.app"
ditto "$BACKGROUND" "$STAGING/.background/background.png"
ln -s /Applications "$STAGING/Applications"

APP_SIZE_MB="$(du -sm "$STAGING" | awk '{print $1}')"
DMG_SIZE_MB="$((APP_SIZE_MB + 20))"

echo "Criando imagem temporária (${DMG_SIZE_MB} MB)…"
hdiutil create \
  -srcfolder "$STAGING" \
  -volname "$VOLUME_NAME" \
  -fs HFS+ \
  -fsargs "-c c=64,a=16,e=16" \
  -format UDRW \
  -size "${DMG_SIZE_MB}m" \
  -ov \
  "$RW_DMG" >/dev/null

echo "Montando para ajustar o layout…"
DEVICE="$(hdiutil attach -readwrite -noverify -noautoopen "$RW_DMG" | awk '/\/dev\// { print $1; exit }')"
MOUNT="/Volumes/${VOLUME_NAME}"

for _ in {1..25}; do
  if [[ -d "$MOUNT/${APP_NAME}.app" ]]; then
    break
  fi
  sleep 0.2
done

if [[ ! -d "$MOUNT/${APP_NAME}.app" ]]; then
  echo "Falha ao montar $MOUNT" >&2
  hdiutil detach "$DEVICE" -force || true
  exit 1
fi

# O Finder precisa de permissão de Automação na primeira execução.
osascript <<EOF
tell application "Finder"
  tell disk "$VOLUME_NAME"
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set bounds of container window to {$WINDOW_X, $WINDOW_Y, $((WINDOW_X + WINDOW_W)), $((WINDOW_Y + WINDOW_H))}
    set viewOptions to icon view options of container window
    set arrangement of viewOptions to not arranged
    set icon size of viewOptions to $ICON_SIZE
    set background picture of viewOptions to file ".background:background.png"
    set position of item "${APP_NAME}.app" of container window to {$APP_ICON_X, $APP_ICON_Y}
    set position of item "Applications" of container window to {$DROP_ICON_X, $DROP_ICON_Y}
    update without registering applications
    delay 1
    close
    open
    delay 1
  end tell
end tell
EOF

sync
hdiutil detach "$DEVICE" -quiet || hdiutil detach "$MOUNT" -force

echo "Compactando…"
hdiutil convert "$RW_DMG" -format UDZO -imagekey zlib-level=9 -o "$FINAL_DMG" >/dev/null
rm -f "$RW_DMG"
rm -rf "$STAGING"

echo
echo "DMG pronto: $FINAL_DMG"
echo "Abra o arquivo para conferir a janela de arrastar para Aplicativos."
echo "Na primeira execução, o macOS pode pedir permissão para o Terminal controlar o Finder — aceite."
