{
  inputs.nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
  inputs.systems.url = "github:nix-systems/default";

  outputs =
    { nixpkgs, systems, ... }:
    let
      inherit (nixpkgs) lib;
      eachSystem = lib.genAttrs (import systems);
      pkgsFor = system: import nixpkgs { inherit system; };
    in
    {
      packages = eachSystem (
        system:
        let
          pkgs = pkgsFor system;
        in
        rec {
          pot-file = pkgs.runCommand "pot-file" { } ''
            ${lib.getExe pkgs.bash} --dump-po-strings ${./main.sh} > $out
          '';

          update-po = pkgs.writeShellScriptBin "update-po" ''
            if [ ! -d "locale" ]; then echo "locale directory not found"; exit 1; fi
            cd locale
            if [ -f messages.pot ] && [ "$(realpath messages.pot)" = "${pot-file}" ]; then echo "po files are up to date"; exit 0; fi

            for pofile in *.po; do
              ${pkgs.gettext}/bin/msgmerge --update --backup=simple "$pofile" ${pot-file}
            done
            ln -sf ${pot-file} messages.pot
          '';

          locale-messages = pkgs.runCommand "locale-messages" { } ''
            mkdir $out
            cd ${./locale}
            for pofile in *.po; do
              lang="''${pofile%.*}"
              mkdir -p "$out/$lang/LC_MESSAGES"
              ${pkgs.gettext}/bin/msgfmt "$pofile" -o "$out/$lang/LC_MESSAGES/messages.mo"
            done
          '';

          default = pkgs.runCommand "hello" { nativeBuildInputs = [ pkgs.makeWrapper ]; } ''
            mkdir -p $out/bin
            install -m 0755 ${./main.sh} $out/bin/hello
            patchShebangs $out/bin/hello
            wrapProgram $out/bin/hello \
              --set TEXTDOMAIN messages \
              --set TEXTDOMAINDIR ${locale-messages} \
              --prefix PATH : ${lib.makeBinPath [ pkgs.lolcat ]}
          '';
        }
      );
    };
}
