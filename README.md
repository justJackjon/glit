# `glit`

## Overview

`glit` is a user-friendly wrapper around [`rsync`](https://rsync.samba.org/), designed to assist in synchronising git repositories with mounted volumes such as networked drives or removable media (e.g., a USB stick). It offers a convenient solution for developers transitioning their work between different machines on a local network, or moving to another machine within physical reach.

> :thought_balloon: _**`glit` was born from a simple desire:**_ to hop from one machine to another without the mental gymnastics of premature git commits. Whilst I fully respect the sanctity of git at logical milestones or end-of-day saves, if I'm just shifting from desk to sofa, I want a seamless transition without losing my focus. And so, to the git purists whose eyes are twitching right now: take a deep breath and, with all due respect, 'git lost' :P. Let's leave the git rituals for meaningful moments, and not for those quick sofa hops.

Other potential [use cases](#use-cases) for `glit` are covered in the relevant section below.

### A glimpse of `glit` in action:

![`glit` basic usage](./assets/glit-basic-usage.gif)

## Table of Contents

- [Use Cases](#use-cases)
- [`glit` is _not_ `git`!](#glit-is-not-git)
- [Features](#features)
- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [Using Optional Configuration Files](#using-optional-configuration-files)
- [Usage](#usage)
- [Examples](#examples)
- [Modules](#modules)
- [Exit Codes](#exit-codes)
- [Troubleshooting](#troubleshooting)
- [Known Issues and Limitations](#known-issues-and-limitations)
- [Uninstallation](#uninstallation)
- [Safety and Data Integrity](#safety-and-data-integrity)
- [License](#license)

## Use Cases

`glit` serves particularly well in the following scenarios:

- **Swift Transitioning Between Local Machines:**
  `glit` enables developers to transition work swiftly across local machines, keeping the work-in-progress local. This approach is especially useful for those who prefer not to expose intermediary or sensitive work through commits, while still valuing an accurate and granular commit history.

- **Data Transfer Between Different Networks:**
  `glit` facilitates secure code transfer via mounted volumes between different networks, eliminating the need for direct network connections and reducing the risk of unwanted access.

- **Deployment to Offline Servers in High-Security Environments:**
  `glit` enables secure code deployment to offline servers in high-security or air-gapped environments where access to traditional VCS might be limited.

- **Quick Testing Across Different Physical Machines:**
  `glit` provides an efficient way to sync and test code across different physical machines without cluttering the remote repository history, especially when the changes are temporary or exploratory.

## `glit` is not `git`!

While `glit` offers flexibility, it is imperative that it is used responsibly and not as a substitute for git best practices. Developers are not discouraged from maintaining granular commits, accurate commit histories, and adhering to established practices such as using short-lived feature branches and following trunk-based development. `glit` is a complementary tool, designed to address specific challenges and enhance your workflow without undermining established best practices in version control.

It is important to recognise that every developer has their own unique workflow, and `glit` seeks to respect this diversity by aiming to accommodate those who may find themselves in situations where committing intermediary, exploratory, or sensitive work is neither ideal nor warranted. `glit` strives to provide a layer of flexibility and control, offering a tailored solution for specific scenarios where traditional VCS might not be the optimal choice.

## Features

- **Intelligent Synchronisation**: `glit` provides [detailed summaries and user confirmations](#a-glimpse-of-glit-in-action) prior to making any changes, ensuring users remain in control of the synchronisation process.
- **Modular Design**: `glit` comprises of multiple script modules, each focusing on a distinct function, making the source code easily understandable and extensible as needed.
- **Cross-Platform Support**: Operates seamlessly on both Linux and MacOS.

## Prerequisites

- [`bash`](https://www.gnu.org/software/bash/)
- [`git`](https://git-scm.com/)
- [`rsync`](https://rsync.samba.org/)
- [`curl`](https://curl.haxx.se/)
- `tput` (generally pre-installed on Unix-based systems)
- `uname` (generally pre-installed on Unix-based systems)
- `realpath` (generally pre-installed on Unix-based systems)

## Installation

To install `glit`, execute the `install_glit.sh` script. The script offers two installation modes. Note that `sudo` or administrative privileges may be necessary for installation.

The installation script will:

- Validate required dependencies.
- Check write permissions for the installation directories.
- Seek confirmation if `glit` is already installed.
- Exit with a status code of 1 if any checks fail.
- Depending on the installation mode, copy or clone the `glit` repository to `/opt/glit`.
- Generate a symlink to the main `glit` script in `/usr/local/bin/glit`.
- Assign the necessary permissions.

### Default Installation

To perform the default installation, retrieve the installation script from the remote repository and execute it with bash. Administrative privileges may be necessary, and if so, prefix the command with `sudo`. Whilst this is the easiest way to get started with `glit`, please heed the security warning below.

> :warning: **Security Warning:** Before executing scripts, especially when piping into `sudo` `bash` from remote locations, always verify the trustworthiness of the source. Thoroughly reviewing the script content to understand its actions is crucial. Exercising this level of caution is a foundational security best practice, regardless of the tool or script in question.

```bash
# WARNING: The following code retrieves a remote script and pipes it into sudo bash.
curl -sSL https://raw.githubusercontent.com/justjackjon/glit/main/install_glit.sh | sudo bash
```

### Local Installation

If the repository has already been cloned locally, execute the installation script from the root of the repository:

```bash
./install_glit.sh local
```

If administrative privileges are required:

```bash
sudo bash ./install_glit.sh local
```

## Using Optional Configuration Files

`glit` supports optional configuration via `.glit_config` files. These files let you define default settings for `glit`, reducing the cognitive overhead associated with remembering specific CLI options or complex configurations. **Any values supplied as command line arguments will override values within `.glit_config` files.**

### Example `.glit_config` File:

```
# NOTE: This is an example `.glit_config` file with default configurations for `glit`.
# Each configuration item corresponds to a matching command line argument. For detailed explanations of these options,
# please refer to the 'Usage' section in the README.

# Whether to initiate the sync immediately, foregoing the change summary. 0 = No, 1 = Yes.
FORCE_ACTION=0

# Whether to auto-respond 'yes' to the sync confirmation prompt. 0 = No, 1 = Yes. Ignored if FORCE_ACTION is set to 1.
AUTO_CONFIRM=0

# Type of mounted volume: 'networked' or 'removable'.
VOLUME_TYPE="networked"

# Name of, or path to, the mounted volume directory, relative to the volume's root.
VOLUME_DIR="SharedRepos"

# Name of the mounted volume.
VOLUME_NAME="z"

# Array of paths to exclude from syncing. Paths are relative to the repo root.
EXCLUSIONS=(".git/" "exclude_this/" "exclude_that/")
```

When `glit` is invoked, it looks for a `.glit_config` file in two locations, in the following order:

1. Within the user's home directory.
2. At the root of the current git repository.

**If a `.glit_config` file is found in the git repository, its settings will override those defined in the user's home directory.**

An example `.glit_config` file is found in the root of this repository. You can use it as a starting template by moving it to the desired location:

```bash
# From the root of the `glit` repository, moves the example file to the user's home directory:
mv .glit_config.example ~/.glit_config
```

## Usage

After installation, you can invoke `glit` using the following syntax:

```bash
glit <push|pull> [optional-local-path-to-repo] [OPTIONS]
```

If your current working directory is within an initialised git repository, there is no need to supply the optional path after the action argument (either `push` or `pull`). `glit` will attempt to resolve this value automatically by looking for the nearest parent directory which is an initialised git repo.

`glit` provides [detailed summaries of planned changes](#a-glimpse-of-glit-in-action) prior to carrying out the synchronisation. This enables users to review and confirm before any changes are made, helping to safeguard against unintentional modifications to either the mounted volume or the local directory.

### Options

- **`-d, --dir`**: Specify the path to the mounted volume directory. Default is `/SharedRepos`. The path is relative to the root of the mounted volume.
- **`-e, --exclude`**: Comma-separated list of paths to exclude from syncing. Paths should be relative to the repository root. Default exclusions include: `node_modules/`, `.git/`, `bin/`, `obj/`.
- **`-f, --force`**: Initiates the sync immediately, foregoing the formatted change summary. This option is a faster alternative to `-y`/`--yes`, which requires a dry run to produce the change summary.
- **`-h, --help`**: Display the help message and exit.
- **`-t, --type`**: Specify the type of mounted volume: 'networked' or 'removable' (e.g., a USB stick). Default is 'networked'.
- **`-v, --version`**: Display the current version of `glit` and exit.
- **`-V, --volume`**: Specify the name of the mounted volume. Default is '`z`'. Ensure the volume is mounted and writable at the following locations: For macOS, under `/Volumes`. For Linux, use `/mnt` for networked volumes and `/media` for removable volumes.
- **`-y, --yes`**: This option bypasses user confirmation by auto-responding 'yes' to the sync confirmation prompt. However, it still produces the formatted change summary for review after the sync. If `-f`/`--force` is also specified, this option is disregarded.

## Examples

### :information_source: Refer to the [Usage](#usage) section for details on default settings and behaviours.

Pushing Changes Within a Git Repo:

```bash
# NOTE: When the current working directory is within a git repo, `glit` will automatically
# find the project root:
glit push --volume my_networked_volume

# If, when mounting your networked volume you called it `z` (the `glit` default):
glit push
```

Using Removable Media (e.g., a USB stick):
```bash
# NOTE: When using 'removable' media, you must specify the `--type`:
# (default `type` is 'networked')
glit push -V my_usb_stick -t removable
```

Specifying the Mounted Volume Directory Path:
```bash
glit push -V my_networked_volume --dir /relative/to/root/of/mounted/volume
```

Pushing Changes When Outside a Git Repo:

```bash
glit push /path/to/local/repo -V my_networked_volume
```

Pushing Changes Excluding Specified Paths:

```bash
# NOTE: The .git directory is ignored by default, but needs to be specified if you override
# the default exclusion list:
glit push --exclude ignore_this,ignore_that,.git

# Assuming none of the following paths are valid from the root of your repo,
# removes the default exclusion list (not recommended):
glit push -e none
glit push -e nothing
glit push -e foobar
```

Pulling Changes with Auto-Confirm:

```bash
glit pull --yes
```

## Modules

`glit` adopts a modular architecture, incorporating several script modules located in the `modules/` directory. Each module caters to a specific functionality and encompasses functions pertinent to its role:

- `variables.sh`: Initialises and declares variables utilised throughout the script.
- `print_fn.sh`: Incorporates functions for formatted console printing.
- `config_parsing.sh`: Handles the parsing of global and repository-specific `.glit_config` files.
- `arg_parsing.sh`: Manages argument parsing and validation.
- `utils.sh`: Incorporates utility functions such as platform determination and volume access check.
- `sync_fns.sh`: Encompasses functions related to repository synchronisation, change detection, user confirmation, and modification of owner and group of synced items.

## Exit Codes

`glit` uses the following non-zero exit codes to indicate that the outcome of the intended operation was unsuccessful. Should you encounter any of these exit codes, the following possible solutions are proposed:

| Code | Description                  | Possible Solution                                                |
| ---- | ---------------------------- | -----------------------------------------------------------------|
| `1`  | Dependencies are missing.    | Install all prerequisites.                                       |
| `2`  | Volume is not accessible.    | Ensure the volume is mounted and writable.                       |
| `3`  | Not within a git repository. | Navigate to a git repository.                                    |
| `4`  | Option requires a value.     | Provide the necessary value for the option.                      |
| `5`  | Git repository not found.    | Verify the correctness of the repository path.                   |
| `6`  | Option is unrecognised.      | Consult the [options section](#options) for valid options.       |
| `7`  | User aborted the operation.  | Execute the command again if needed.                             |
| `8`  | Platform is not supported.   | Verify platform support (Linux or MacOS).                        |
| `9`  | Volume is not mounted.       | Mount the specified volume.                                      |
| `10` | Mandatory argument missing.  | Consult the [options section](#options) for mandatory arguments. |
| `11` | Argument is unrecognised.    | Consult the [options section](#options) for valid arguments.     |

## Troubleshooting

- Confirm the installation and availability in the `PATH` of all prerequisites.
- Verify the mounted status and writability of the mounted volume.
- Ascertain user permissions for accessing the mounted volume and installation directories.
- In case of issues, refer to the error messages and corresponding [exit codes](#exit-codes) for guidance and potential solutions.

## Known Issues and Limitations

- :heavy_exclamation_mark: [`glit` is not `git`](#glit-is-not-git). By design, you should manage your git workflow separately to `glit`.
- For any other known issues or limitations of `glit`, refer to the [Issues](https://github.com/justjackjon/glit/issues) section on GitHub.

## Uninstallation

To uninstall `glit`, manually eliminate the files and directories created during the installation process. These include the `glit` repository located at `/opt/glit` and the symlink in `/usr/local/bin/glit`.

## Safety and Data Integrity

Since `glit` deals with file synchronisation, users are advised to back up crucial data before utilising the tool to avoid unintended data loss.

## License

`glit` is licensed under the [MIT License](https://github.com/justjackjon/glit/blob/main/LICENSE). Refer to the license file for detailed terms and conditions.
