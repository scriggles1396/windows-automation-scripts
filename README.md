# Windows Automation Scripts

A collection of reusable PowerShell and Windows automation scripts, organized into personal convenience tools and work-related industrial/OT utilities.

## Repository layout

```text
.
├── Personal/
│   ├── Media/
│   ├── Network/
│   ├── System/
│   └── Utilities/
├── Work/
│   ├── Industrial/
│   ├── Network/
│   ├── OT/
│   └── Utilities/
├── templates/
│   └── PowerShell-Script-Header.ps1
├── docs/
│   ├── Script-Index.md
│   ├── Requirements.md
│   └── <one guide per published script>
├── .gitignore
├── LICENSE
└── SECURITY.md
```

- **Personal** contains convenience scripts created to make everyday tasks easier.
- **Work** contains generic industrial, operational technology (OT), networking, and automation utilities. Work scripts must be sanitized before publication and must not contain customer or employer information.

Folders can be added or renamed as the collection grows. A script that develops multiple source files, tests, releases, or substantial standalone documentation may eventually be moved into its own repository.

## Using a script

1. Open the script and read it completely.
2. Review its requirements, parameters, permissions, and possible side effects.
3. Test it in a safe, non-production environment.
4. Run it with the least privilege needed.
5. Keep a backup or recovery plan when a script changes files, devices, or configuration.

Scripts are provided as examples and utilities, without a guarantee that they are suitable for a particular system or environment.

## Script guides

Start with the [script index](docs/Script-Index.md). It links to each available script's
requirements, setup instructions, usage, outputs, safety notes, and troubleshooting guidance.

Before running a script, check the [common requirements](docs/Requirements.md) and the
requirements listed for that specific script. Some scripts rely on built-in Windows tools;
others need separately installed programs.

## AI usage disclosure

Some scripts, code, comments, tests, or documentation in this repository may be created or assisted by artificial intelligence tools, including ChatGPT from OpenAI.

AI assistance is treated as a development tool. AI-generated or AI-assisted output is reviewed and tested by a human before it is intentionally published for use. That review reduces risk but does not guarantee that every issue has been found.

Before running any script, users should independently review the code, confirm that it is appropriate for their environment, understand its effects, and test it safely. Each script should use the header in `templates/PowerShell-Script-Header.ps1` to state whether AI assistance was used.

## Safety and privacy

Do not commit:

- credentials, passwords, tokens, or connection strings
- customer, employer, or personally identifying information
- private hostnames, domains, IP addresses, network diagrams, or asset inventories
- certificates, private keys, signing material, or VPN profiles
- proprietary configuration, logs, exports, backups, or production data
- internal procedures or details that could weaken an organization's security

Use obvious placeholders such as `example.invalid`, `192.0.2.10`, `198.51.100.20`, and `203.0.113.30` in examples. These IP ranges and the `.invalid` domain are reserved for documentation.

See [SECURITY.md](SECURITY.md) for reporting and publication guidance.

## Contributing a script

Before publishing a script:

- remove or replace environment-specific and sensitive values
- add the reusable script header and complete every field
- document requirements, examples, outputs, and potentially destructive behavior
- test in a safe environment
- prefer parameters or configuration files over embedded values
- never include secrets, private certificates, or real operational identifiers

## License

This repository uses the [MIT License](LICENSE), a permissive open-source license that allows reuse, modification, and redistribution while requiring preservation of the license and copyright notice.

Individual third-party components may have their own licenses and should be identified where applicable.
