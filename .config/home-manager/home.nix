{ config, pkgs, ... }:

{
 home.username = "wfaler";
 home.homeDirectory = "/home/wfaler";

 home.stateVersion = "23.05"; # Please read the comment before changing.

 home.packages = [
    pkgs.kubectl
    pkgs.kubectx
    pkgs.kubernetes-helm
    pkgs.jq
    pkgs.yq
    pkgs.bat
    pkgs.k3d
    pkgs.rclone
    pkgs.openssl
    pkgs.wget
    pkgs.gnumake
    pkgs.bazelisk
    pkgs.gnupg
    pkgs.hcloud
    pkgs.go_1_22
    pkgs.buf
    pkgs.protoc-gen-go
    pkgs.golangci-lint
    pkgs.protobuf
    pkgs.dig
    pkgs.rustup
    pkgs.cargo-nextest
    pkgs.git
    pkgs.git-secret
    pkgs.lazygit
    pkgs.gh
    pkgs.bash
    pkgs.diffutils
    pkgs.zsh
    pkgs.oh-my-zsh
    pkgs.cloc
    pkgs.direnv
    pkgs.ansible_2_16
    pkgs.terraform
    pkgs.checkov
    pkgs.zellij
    pkgs.ripgrep
    pkgs.sqlite
    pkgs.nerdfonts
    pkgs.whois
    pkgs.stow
  ];
  


  programs.git = {
   enable = true;
   userName = "Wille Faler";
   userEmail = "wfaler@chaordic.io";
   extraConfig = {
    init.defaultBranch = "main";
    credential = {
      helper = "cache --timeout=600"; # Sets the cache timeout to 600 seconds
    };
   };
  };
  
  programs.direnv = {
    enable = true;
    enableZshIntegration = true;
  };
  
    programs.zsh = {
    enable = true;
    enableCompletion = true;

    oh-my-zsh = {
      enable = true;
      theme = "robbyrussell";
      plugins = ["git" "sudo" "docker" "kubectl"];
    };
    plugins = [
      {
        name = "zsh-nix-shell";
        file = "nix-shell.plugin.zsh";

        src = pkgs.fetchFromGitHub {
          owner = "chisui";
          repo = "zsh-nix-shell";
          rev = "v0.7.0";
          sha256 = "149zh2rm59blr2q458a5irkfh82y3dwdich60s9670kl3cl5h2m1";
        };
      }
    ];
    sessionVariables = {
      EDITOR = "nvim";
      NIXPKGS_ALLOW_UNFREE = 1;
      GOPATH = "$HOME/apps/go";
      USE_GKE_GCLOUD_AUTH_PLUGIN = "True";
      PATH = "$HOME/.cargo/bin:$HOME/.rbenv/shims:$HOME/.local/bin:$HOME/.nix-profile/bin:$GOPATH/bin:$HOME/apps/bin:$PATH:$HOME/.local/share/coursier/bin";
    };
    shellAliases = {
      gp = "git pull --no-rebase";
      vim = "nvim";
      vi = "nvim";
    };
    initExtra = ''mkdir -p $HOME/apps/go/bin && mkdir -p $HOME/.config/nvim
export PYENV_ROOT="$HOME/.pyenv"
[[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init -)"
source "$HOME/.sdkman/bin/sdkman-init.sh"
eval "$($HOME/.rbenv/bin/rbenv init - zsh)"
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion
'';
  };
  
  # Home Manager is pretty good at managing dotfiles. The primary way to manage
  # plain files is through 'home.file'.
  home.file = {
    # # Building this configuration will create a copy of 'dotfiles/screenrc' in
    # # the Nix store. Activating the configuration will then make '~/.screenrc' a
    # # symlink to the Nix store copy.
    # ".screenrc".source = dotfiles/screenrc;

    # # You can also set the file content immediately.
    # ".gradle/gradle.properties".text = ''
    #   org.gradle.console=verbose
    #   org.gradle.daemon.idletimeout=3600000
    # '';
  };

  # You can also manage environment variables but you will have to manually
  # source
  #
  #  ~/.nix-profile/etc/profile.d/hm-session-vars.sh
  #
  # or
  #
  #  /etc/profiles/per-user/wfaler/etc/profile.d/hm-session-vars.sh
  #
  # if you don't want to manage your shell through Home Manager.
  home.sessionVariables = {
    EDITOR = "nvim";
    GOPRIVATE = "github.com/chaordic-io/*";
  };

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;
}
