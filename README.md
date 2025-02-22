# V Upgrader and Version Manager

Upgrades to the latest version of V, or manages more versions of V on the same machine, supporting all platforms including RISC-V, as simple es `rustup`.

* Small. Written in `bash`, easily extensible.
* Fast. Downloads and unpacks pre-built binary builds.
* Portable. Writes only to the user home directory.
* Simple. Switches the version globally, no environment variable changes needed.
* Efficient. Just run `vup up`.

Platforms: `darwin-amd64`, `darwin-arm64`, `linux-amd64`, `linux-arm64`, `linux-riscv64`, `windows-x64`.

## Getting Started

Make sure that you have `bash` 4 or newer and `curl` available, execute the following command:

    curl -fSs https://raw.githubusercontent.com/prantlf/vup/master/install.sh | bash

Before you continue, make sure that you have the following tools available: `curl`, `grep`, `jq`, `ln`, `rm`, `rmdir`, `sed`, `tar` (non-Windows), `uname`, `unxz` (non-Windows), `unzip` (Windows). It's likely that `jq` will be missing. You can install it like this on Debian: `apt-get install -y jq`.

Install the latest version of V, if it hasn't been installed yet:

    vup install latest

Upgrade both the installer script and the V language, if they're not the latest versions, and delete the previously active latest version from the disk too:

    vup up

## Installation

Make sure that you have `bash` 4 or newer and `curl` available, execute the following command:

    curl -fSs https://raw.githubusercontent.com/prantlf/vup/master/install.sh | bash

Both the `vup` and `v` should be executable in any directory via the `PATH` environment variable. The installer script will modify the RC-file of the shell, from which you launched it. The following RC-files are supported:

    ~/.bashrc
    ~/.zshrc
    ~/.config/fish/config.fish

If you use other shell or more shells, update the other RC-files by putting both the installer directory and the V binary directory to `PATH`, for example:

    $HOME/.vup:$HOME/.v:$PATH

Start a new shell after the installer finishes. Or extend the `PATH` in the current shell as the instructions on the console will tell you.

## Locations

| Path     | Description                                          |
|:---------|:-----------------------------------------------------|
| `~/.vup` | directory with the installer script and versions of V |
| `~/.v`   | symbolic link to the currently active version of V    |

For example, with the V weekly.2024.32 activated:

    /home/prantlf/.vup
      ├── 0.4.7           (another version)
      ├── vup             (installer script)
      └── weekly.2024.32  (linked to /home/prantlf/.v)

## Usage

    vup <task> [version]

    Tasks:

      current              print the currently selected version of V
      latest               print the latest version of V for download
      local                print versions of V ready to be selected
      remote               print versions of V available for download
      update               update this tool to the latest version
      upgrade              upgrade V to the latest and remove the current version
      up                   perform both update and upgrade tasks
      install <version>    add the specified or the latest version of V
      uninstall <version>  remove the specified version of V
      use <version>        use the specified or the latest version of V
      help                 print usage instructions for this tool
      version              print the version of this tool

You can enter just `MAJ` or `MAJ.MIN` as `<version>`, instead of the full `MAJ.MIN.PAT`. When using the `install` or `use` tasks, the *most* recent full version that starts by the entered partial version will be picked. When using the `uninstall` task, the *least* recent full version that starts by the entered partial version will be picked.

## Debugging

If you enable `bash` debugging, every line of the script will be printed on the console. You'll be able to see values of local variables and follow the script execution:

    bash -x vup ...

You can debug the installer too:

    curl -fSs https://raw.githubusercontent.com/prantlf/vup/master/install.sh | bash -x

## Contributing

In lieu of a formal styleguide, take care to maintain the existing coding style. Lint and test your code.

## License

Copyright (c) 2024 Ferdinand Prantl

Licensed under the MIT license.
