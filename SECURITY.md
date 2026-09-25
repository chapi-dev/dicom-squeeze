# Security policy

## Supported versions

Only the latest commit on `main` is supported. This is a mockup project with a rolling
release and no maintenance branches.

## Reporting a vulnerability

Report privately through GitHub Security Advisories:

**[Open a draft security advisory](https://github.com/chapi-dev/dicom-squeeze/security/advisories/new)**

Do not open a public issue for a vulnerability.

Please include the affected file and version, a description of the impact, steps to
reproduce, and any suggested fix. Expect an acknowledgement within a week.

## Scope

DICOM Squeeze is a static single-page application. It has **no backend, no database, no
authentication and no secrets**. All computation happens in the browser, and no data leaves
it.

In scope:

- Cross-site scripting or any other client-side injection in the built application.
- A supply-chain vulnerability in a direct dependency.
- A GitHub Actions workflow vulnerability: privilege escalation, script injection, or
  untrusted code execution in a `pull_request_target` context.
- A leaked credential anywhere in the repository or its history.

Out of scope:

- The accuracy of a compression ratio or a storage price. That is a
  [data accuracy issue](https://github.com/chapi-dev/dicom-squeeze/issues/new?template=data_accuracy.yml),
  not a vulnerability.
- Missing security headers on GitHub Pages, which are outside this project's control.
- Denial of service against a static site.

## Automated security measures

| Measure                    | Where                                    |
| -------------------------- | ---------------------------------------- |
| CodeQL, security-extended  | `.github/workflows/codeql.yml`           |
| CodeQL for Actions         | Same workflow, `actions` language        |
| Dependency review on PRs   | `.github/workflows/dependency-review.yml` |
| Dependabot updates         | `.github/dependabot.yml`                 |
| Secret scanning            | Repository settings, push protection on  |
| Least-privilege tokens     | Every workflow declares `permissions`    |

## Notes for contributors

**Do not commit patient data.** No DICOM files, no anonymised studies, no identifiers. A
`preToolUse` hook in `.github/hooks/` blocks agents from creating files with DICOM
extensions; treat that as a backstop, not a substitute for judgement.

**`pull_request_target` runs with write access against the base branch.** The triage
workflow uses it, and deliberately never checks out or executes code from the pull request
head. If you edit that workflow, preserve that property — it is the entire vulnerability
class.

**The application has no secrets by design.** If a change appears to need one, that is a
signal the change does not belong in this repository.
