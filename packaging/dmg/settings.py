# Configuração do dmgbuild para o DMG gerado no GitHub Actions.
# O Finder não pode ser automatizado no runner; este arquivo grava o
# mesmo layout do scripts/create-dmg.sh direto no .DS_Store.
# `defines` é injetado pelo dmgbuild via -D.

application = defines["app"]  # noqa: F821
background = defines["background"]  # noqa: F821

files = [application]
symlinks = {"Applications": "/Applications"}

default_view = "icon-view"
icon_size = 128
text_size = 12
icon_locations = {
    "copyMemory.app": (150, 185),
    "Applications": (450, 185),
}

window_rect = ((200, 120), (600, 400))

show_status_bar = False
show_tab_view = False
show_toolbar = False
show_pathbar = False
show_sidebar = False
