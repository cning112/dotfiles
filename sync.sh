#! /bin/bash

DOTFILES=(.bash_profile .gitconfig .gitignore .zshrc .ideavimrc)

for dotfile in $(echo ${DOTFILES[*]});
do
    cp ~/$(echo $dotfile) ~/dev/dotfiles/$(echo $dotfile) 
done
