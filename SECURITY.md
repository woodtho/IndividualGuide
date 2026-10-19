# Reporting security issues

For vulnerabilities or accidental credential exposure, contact the maintainer using the email in DESCRIPTION. Avoid publishing credentials, private data or exploit details in a public issue.

Open `.igpx` projects only from sources you trust. They can contain R scripts and native serialized R objects. The desktop app runs a private local Shiny session; this does not sandbox arbitrary R code. Use environment variables or a credential store for database secrets and inspect diagnostics before sharing them.
