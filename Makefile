.PHONY: test clean all install install-bash install-python install-tmux install-vim

install: install-bash install-python install-tmux install-vim

install-bash:
	rm -rf ~/.bash.d
	rm -rf ~/.bash_logout
	rm -rf ~/.bash_profile
	rm -rf ~/.bashrc
	ln -s `pwd`/bash/bash.d ~/.bash.d
	ln -s `pwd`/bash/bash_logout ~/.bash_logout
	ln -s `pwd`/bash/bash_profile ~/.bash_profile
	ln -s `pwd`/bash/bashrc ~/.bashrc

install-python:
	rm -rf ~/.ipython
	rm -rf ~/.pdbrc
	rm -rf ~/.pypirc
	rm -rf ~/.python-startup.py
	ln -s `pwd`/python/ipython ~/.ipython
	ln -s `pwd`/python/pdbrc ~/.pdbrc
	ln -s `pwd`/python/python-startup.py ~/.python-startup.py

install-tmux:
	rm -rf ~/.tmux.conf
	ln -s `pwd`/tmux/tmux.conf ~/.tmux.conf

install-vim:
	mkdir -p ~/.vim
	rm -rf ~/.vim/pack ~/.vim/UltiSnips
	rm -rf ~/.vimrc
	rm -rf ~/.vintrc.yaml
	git submodule update
	ln -sf `pwd`/vim/UltiSnips ~/.vim/
	ln -sf `pwd`/vim/pack ~/.vim/
	ln -sf `pwd`/vim/vimrc ~/.vimrc
	ln -sf `pwd`/vim/vintrc.yaml ~/.vintrc.yaml
	ln -sf `pwd`/vim/coc-settings.json ~/.vim/coc-settings.json
	mkdir -p ~/.config/coc/extensions
	ln -sf `pwd`/vim/coc-package.json ~/.config/coc/extensions/package.json
