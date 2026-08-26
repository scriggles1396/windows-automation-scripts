# Security and responsible publication

## Reporting a security concern

Please do not publish sensitive details in a public issue. If GitHub private vulnerability reporting is enabled for this repository, use it for suspected vulnerabilities. Otherwise, contact the repository owner privately through an appropriate channel.

Do not include credentials, tokens, customer information, private network details, certificates, production logs, or exploit-ready operational data in a report.

## Publishing work and OT scripts

Only publish generic, sanitized examples that you are authorized to share. Before committing a work-related script:

- confirm that the script and its underlying process may be shared publicly
- remove employer, customer, site, asset, vendor-contract, and project identifiers
- replace real hostnames, domains, IP addresses, usernames, paths, and device names
- remove credentials, tokens, certificates, private keys, connection strings, and embedded secrets
- remove production data, packet captures, logs, exports, backups, and proprietary configuration
- check comments, examples, screenshots, test data, commit history, and filenames for sensitive information
- test the sanitized version separately

Use documentation-only addresses such as `192.0.2.10`, `198.51.100.20`, or `203.0.113.30`, and domains under `example.invalid`.

## Operational caution

Industrial and OT environments can have safety, availability, and production consequences. Independently review and test scripts in a safe environment, follow site change-control procedures, use least privilege, and have an approved recovery plan before production use.
