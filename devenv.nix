{ pkgs, ... }:
{
  packages = with pkgs; [
    nodejs_24
    bun
  ];

  cachix.pull = [ "devenv" ];
}
