#!/usr/bin/env bash
set -e

function main {

  # Whether a command exists.
  function installed {
    $(which "$1" &> /dev/null)

    return $?
  }

  local INSTALL_CMD=""

  if installed brew; then
    INSTALL_CMD="brew install"
  elif installed apt-get; then
    INSTALL_CMD="sudo apt-get install -y"
  elif installed yum; then
    INSTALL_CMD="sudo yum install"
  elif installed pacman; then
    INSTALL_CMD="sudo pacman -S"
  else
    echo "How do you install things on this machine?!?"
  fi

  # Best-effort install. Prone to breakage.
  function install {
    $INSTALL_CMD $1 1> /dev/null
  }

  # Install the thing if it doesn't exist.
  function ensure {
    if installed "$1"; then
      return
    fi

    install "$1"
  }

  function verify_hash {
    local integrity=`openssl sha1 <<< "$2"`

    # Some systems print junk before the hash.
    if ! installed brew; then
      integrity=`echo $integrity | awk '{print $2}'`
    fi

    if [[ "$integrity" != "$1" ]]; then
      return 1
    fi

    return
  }

  # Install to a /tmp file and verify the integrity hash.
  function install_via_curl {
    local install_script=`curl -fsSL "$1"`

    if ! verify_hash "$2" "$install_script"; then
      echo "Hmmm, an install script looks sketchy. The integrity doesn't match."
      echo "    URL: $1"
      exit 1
    fi

    set +e
    bash <<< "$install_script"
    set -e
  }

  function ensure_apt_add_command {
    if installed add-apt-repository; then
      return
    fi

    install software-properties-common
    install python-software-properties
  }

  function install_make {
    if installed make; then
      return
    fi

    install build-essential
  }

  function install_zsh {
    if installed zsh; then
      return
    fi

    install zsh

    # Don't attempt to change shell on Travis CI.
    # The build will hang forever.
    if [[ ! -z "$CI" ]]; then
      return
    fi

    chsh -s `which zsh`
  }

  function install_oh_my_zsh {
    if [[ -d ~/.oh-my-zsh ]]; then
      return
    fi

    install_via_curl https://cdn.rawgit.com/robbyrussell/oh-my-zsh/d848c94804918138375041a9f800f401bec12068/tools/install.sh f423ddfb1d0b6a849b229be5b07a032c10e13c6f &> /dev/null
  }

  function install_yarn {
    if installed yarn; then
      return
    fi

    local pkg="yarn"

    # Don't install node too.
    if installed brew; then
      pkg="yarn --ignore-dependencies"
    fi

    if installed apt-get; then
      ensure_apt_add_command

      # Add yarn package provider.
      curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | sudo apt-key add -
      echo "deb https://dl.yarnpkg.com/debian/ stable main" | sudo tee /etc/apt/sources.list.d/yarn.list

      sudo apt-get update
    fi

    install "$pkg"
  }

  function install_ruby {
    if installed ruby; then
      return
    fi

    local pkg="ruby"
    if installed apt-get; then
      pkg="ruby-full"
    fi

    install "$pkg"
  }

  function install_tmuxinator {
    if installed tmuxinator; then
      return
    fi

    sudo gem install tmuxinator
  }

  function install_silver_searcher {
    if installed ag; then
      return
    fi

    local pkg_name="the_silver_searcher"

    # Goes by a different name on aptitude.
    if installed apt-get; then
      pkg_name="silversearcher-ag"
    fi

    install "$pkg_name"
  }

  function install_llama_zsh_theme {
    if [[ -f ~/.oh-my-zsh/themes/llama.zsh-theme ]]; then
      return
    fi

    local theme=`curl https://cdn.rawgit.com/PsychoLlama/llama.zsh-theme/29f66554ed63609becbbd60e80f75aa4a8e72c49/llama.zsh-theme`

    if ! verify_hash "803c3c044e238f54ecf91d62c729bc746fe6c0ee" "$theme"; then
      echo "llama zsh theme install failed. The hash doesn't match."
      exit 1
    fi

    echo "$theme" > ~/.oh-my-zsh/themes/llama.zsh-theme
  }

  # A node version manager, alternative to nvm.
  function install_n {
    if installed n; then
      return
    fi

    git clone https://github.com/tj/n.git ~/.n-bin &> /dev/null

    pushd ~/.n-bin &> /dev/null
    sudo make &> /dev/null
    popd &> /dev/null

    rm -rf ~/.n-bin
  }

  function install_node {
    if installed node; then
      return
    fi

    N_PREFIX=~/.n n latest
  }

  function install_vim_plug {
    local target=~/.local/share/nvim/site/autoload/plug.vim

    if [[ -f "$target" ]]; then
      return
    fi

    curl -fLo ~/.local/share/nvim/site/autoload/plug.vim --create-dirs \
    https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
  }

  function install_neovim {
    if installed nvim; then
      return
    fi

    local pkg="neovim"
    if installed apt-get; then
      source /etc/os-release

      local ppa="ppa:neovim-ppa/unstable"
      local major_version="${VERSION:0:2}"

      # High chance this will break some day.
      if [[ "$major_version" > 15 ]]; then
        ppa="ppa:neovim-ppa/stable"
      fi

      # Add the neovim ppa.
      sudo add-apt-repository "$ppa" <<< "\n"
      sudo apt-get update

      install python-dev
      install python-pip
      install python3-dev
      install python3-pip
    fi

    install "$pkg"
    mkdir -p ~/.vim/backup
    sudo chmod 777 ~/.vim/backup
  }

  function install_neovim_plugins {
    if ! python3 -c "import neovim" &> /dev/null; then
      pip3 install neovim &> /dev/null
    fi

    # Source the vimrc in non-interactive mode.
    nvim\
      -u /dev/null\
      +"silent so ~/.config/nvim/init.vim"\
      +PlugInstall +UpdateRemotePlugins +qa
  }

  function install_vint {
    if ! installed vint; then
      pip3 install vim-vint &> /dev/null
    fi
  }

  ensure curl
  ensure openssl
  ensure tmux
  ensure python3

  install_make
  install_zsh
  install_oh_my_zsh
  install_yarn
  install_ruby
  install_tmuxinator
  install_silver_searcher
  install_llama_zsh_theme
  install_n
  install_node
  install_vim_plug
  install_neovim
  install_neovim_plugins
  install_vint
}

main
