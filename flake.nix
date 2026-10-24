{
  description = "cix: NixOS configurations for every machine I run";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    # Separate pin: the CUDA packages recompile locally on every bump
    nixpkgs-cuda.url = "github:NixOS/nixpkgs/nixos-unstable";
    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    agenix.url = "github:ryantm/agenix";
    agenix.inputs.nixpkgs.follows = "nixpkgs";
    plasma-manager.url = "github:nix-community/plasma-manager";
    plasma-manager.inputs.nixpkgs.follows = "nixpkgs";
    plasma-manager.inputs.home-manager.follows = "home-manager";
    chandra-src = {
      url = "github:datalab-to/chandra";
      flake = false;
    };
    chandra-model = {
      url = "git+https://huggingface.co/datalab-to/chandra-ocr-2";
      flake = false;
    };
    # The private server repo: draba reads the server's registry and the share's secret from it
    pve = {
      url = "git+ssh://git@github.com/cardaria/pve";
      flake = false;
    };
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      disko,
      home-manager,
      agenix,
      ...
    }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      cudaPkgs = import inputs.nixpkgs-cuda {
        inherit system;
        config.allowUnfree = true;
      };
      formatter = pkgs.nixfmt-tree;

      # The server's machines and services, read from the pve repo's registry
      registry =
        (nixpkgs.lib.evalModules { modules = [ "${inputs.pve}/modules/nixos/pve/services.nix" ]; })
        .config.pve;

      # The server's domain and addresses, which no file here may contain (the docs check)
      private = pkgs.writeText "pve-private" (
        nixpkgs.lib.concatLines (
          [ registry.domain ]
          ++ builtins.filter (a: a != "127.0.0.1") (builtins.attrValues registry.addresses)
          ++ builtins.attrValues registry.networks
        )
      );
    in
    {
      nixosConfigurations.draba = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = {
          chandraSrc = inputs.chandra-src;
          pveSrc = inputs.pve;
          inherit cudaPkgs registry;
        };
        modules = [
          disko.nixosModules.disko
          home-manager.nixosModules.home-manager
          agenix.nixosModules.default
          ./hosts/draba
          ./modules/nixos/desktop.nix
          ./modules/nixos/login.nix
          ./modules/nixos/1password.nix
          ./modules/nixos/packages.nix
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.sharedModules = [ inputs.plasma-manager.homeModules.plasma-manager ];
            home-manager.extraSpecialArgs = {
              chandraModel = inputs.chandra-model;
              inherit registry;
            };
            home-manager.users.cardaria = import ./home/cardaria;
          }
        ];
      };

      # The host's pkgs, which allows unfree CUDA for local AI
      packages.${system} =
        import ./pkgs {
          pkgs = self.nixosConfigurations.draba.pkgs;
          inherit cudaPkgs;
          chandraSrc = inputs.chandra-src;
        }
        // {
          disko = disko.packages.${system}.disko;
          agenix = agenix.packages.${system}.default;
          age = pkgs.age;
        };

      formatter.${system} = formatter;

      devShells.${system}.default = pkgs.mkShell {
        packages = [
          pkgs.nixd
          pkgs.nixfmt
          formatter
          # Packaging helpers
          pkgs.nurl
          pkgs.nix-update
          pkgs.yq-go
        ];
      };

      checks.${system} = {
        cix-update =
          pkgs.runCommand "cix-update-tests"
            {
              nativeBuildInputs = [
                pkgs.python3
                pkgs.bash
                pkgs.git
                pkgs.coreutils
                pkgs.util-linux
                pkgs.jq
                pkgs.age
                pkgs.openssh
                pkgs.gnugrep
                pkgs.hostname
              ];
            }
            ''
              python ${./modules/home/cix}/test-update.py
              python ${./modules/home/cix}/test-update-pve.py
              python ${self}/modules/home/cix/test-maintenance.py
              touch "$out"
            '';
        docs-sources =
          pkgs.runCommand "cix-docs-sources"
            {
              nativeBuildInputs = [
                pkgs.bash
                pkgs.findutils
                pkgs.gawk
                pkgs.gnugrep
                pkgs.yq-go
              ];
            }
            ''
              bash ${./wiki/_check.sh} ${self} ${private}
              touch "$out"
            '';
        formatting =
          pkgs.runCommand "cix-formatting"
            {
              nativeBuildInputs = [
                pkgs.nixfmt
                pkgs.findutils
              ];
            }
            ''
              find ${self} -type f -name '*.nix' -exec nixfmt --check {} +
              touch "$out"
            '';
      };
    };
}
