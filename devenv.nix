{ pkgs, ... }:
{
  packages = with pkgs; [
    nodejs_26
    bun
  ];

  cachix.pull = [ "devenv" ];
}
