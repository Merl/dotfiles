# ~/.bash_profile: bash login shells read this instead of ~/.profile.
# Only defer to ~/.profile, which sets PATH and sources ~/.bashrc once.
# (Replaces Git for Windows' default, which sourced ~/.bashrc a second time.)
[ -f "$HOME/.profile" ] && . "$HOME/.profile"
