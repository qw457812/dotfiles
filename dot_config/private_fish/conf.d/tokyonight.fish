set style moon
set theme tokyonight_{$style}

set src ~/.config/tokyonight.nvim/extras/fish_themes/{$theme}.theme
set dst ~/.config/fish/themes/{$theme}.theme

[ -L $dst ]
or ln -s $src $dst

fish_config theme choose $theme
