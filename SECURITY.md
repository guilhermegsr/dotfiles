# Security

This repository ships shell, SSH, and backup tooling that runs with your user privileges and can handle private keys.

## Reporting a vulnerability

Do **not** open a public GitHub issue for problems that involve:

- SSH private keys, `authorized_keys`, or host configs
- Backup archives (`.tar.gz`, `.enc`, `.age`) or their passphrases
- Tokens or identity data in `local.zsh` / `git/config.local`

Email the maintainer at the address on the Git commits / GitHub profile, or use GitHub's private vulnerability reporting if it is enabled on the repository.

Include:

- A description of the issue and impact
- Steps to reproduce (with dummy keys, never real ones)
- Affected scripts (`install.sh`, `backup.sh`, `restore.sh`, `ssh-new`, …)

## Handling backups

- Default backups are encrypted. An unencrypted archive (`./backup.sh --plain`) contains SSH private keys.
- Only restore archives **you created** on a machine you trust. `restore.sh` allowlists paths, but a backup from a compromised host can still replace your keys.
- Do not commit `*.enc`, `*.age`, `local.zsh`, or `config.local`.
