# Evergreen
Azur Promilia client patch to be used with [Zetsa](https://git.xeondev.com/zetsa/zetsa).

## Features
- Redirects the game's web requests to configured endpoints.
- Eliminates any anti cheat presence from the client, making it possible to play using wine on linux.
- Bonus: disables the "censorship" functionality, allowing to view character models at any angle.

## Requirements
In order to build Evergreen you need:
- Zig Compiler, version `0.16.0`: [Linux](https://ziglang.org/download/0.16.0/zig-x86_64-linux-0.16.0.tar.xz)/[Windows](https://ziglang.org/download/0.16.0/zig-x86_64-windows-0.16.0.zip)

## Compilation
#### Linux
```sh
# Assuming you have git(1) installed.
git clone https://git.xeondev.com/zetsa/evergreen.git
cd evergreen
. ./envrc # The `envrc` script will setup the zig compiler for you.
zig build -Doptimize=ReleaseSmall
```
#### Windows
```sh
# Assuming you're running this in powershell and have git(1) installed.
git clone https://git.xeondev.com/zetsa/evergreen.git
cd evergreen
./envrc.ps1 # The `envrc.ps1` script will setup the zig compiler for you.
zig build -Doptimize=ReleaseSmall
```

## Installation
First of all, you have to get the compatible game client, the current supported version is CB2.

Then, after the compilation, grab the `AzurPromilia.exe` from `zig-out/bin/` directory and
move it to the game directory (you should replace the original `AzurPromilia.exe` with the one you've just built)

## Configuration
The configuration of evergreen is done by editing `config.zon` and (re)compiling the source code.

## Connecting
Make sure you have [Zetsa](https://git.xeondev.com/zetsa/zetsa) up and running.
Run the `AzurPromilia.exe`, at startup, you'll see a prompt where you should enter your ID, the requirement for it is to be an alphanumeric string less than 128 characters. Next, you should see a server selection pop-up. Pick the `zetsa` server and the last version entry. After that, you should be able to enter the game. Have fun!
