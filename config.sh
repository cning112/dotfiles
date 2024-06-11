#! /bin/bash

DOTFILES=(.bash_profile .gitconfig .gitignore .zshrc .ideavimrc)

for dotfile in $(echo ${DOTFILES[*]});
do
    cp ~/dev/dotfiles/$(echo $dotfile) ~/$(echo $dotfile)
done

# create a link for vimrc
ln -s ~/.ideavimrc ~/.vimrc
