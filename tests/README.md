# Test suite

The GitHub Actions workflow intentionally contains only orchestration.

- `static/` validates source structure, shell code, PowerShell syntax, chezmoi templates, and the encoded AllSigned bridge.
- `linux/` owns the Debian and Arch integration fixture and post-bootstrap assertions.
- `windows/` owns Windows fixture setup, normal-policy assertions, AllSigned assertions, and update fixtures.

Keep reusable validation logic here instead of embedding large scripts in `.github/workflows/validate.yml`.
