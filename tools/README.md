# tools/

## `sloplint.mjs`

Hallmark's mechanical gate checker, vendored **byte-identical** from
`nutlope/hallmark` (MIT), `skills/hallmark/scripts/sloplint.mjs`.

It is here because CI needs it and the skill tree does not ship: `.agents/` is
gitignored (8.6MB, mostly theme screenshots), so a checkout has no
`.agents/skills/hallmark/scripts/sloplint.mjs` to run. The file is zero-dependency
and Node 18+, and its one sibling read — a photo library — is wrapped in a
try/catch, so it runs correctly on its own.

Vendored rather than installed at CI time on purpose: a gate that fetches from a
third-party default branch on every run can fail for reasons that have nothing to
do with the commit under test.

**To update**, re-copy and keep it byte-identical so the diff is reviewable:

```sh
npx skills add nutlope/hallmark          # refreshes .agents/, per skills-lock.json
cp .agents/skills/hallmark/scripts/sloplint.mjs tools/sloplint.mjs
```

The gate command and the waived reflexes live in `DESIGN.md` § Exports.
