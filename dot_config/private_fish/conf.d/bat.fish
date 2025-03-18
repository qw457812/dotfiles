set style moon
set theme tokyonight_{$style}

set src ~/.config/tokyonight.nvim/extras/sublime/{$theme}.tmTheme
set dst ~/.config/bat/themes/{$theme}.tmTheme

if not test -L $dst
    ln -s $src $dst
    bat cache --build
end
