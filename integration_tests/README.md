# Engine integration tests

Tests in this directory run against a separate Gen1Recomp checkout. Set
`GEN1RECOMP_ROOT` to a checkout at tag `v0.2.74`, commit
`9545ebbb839a8a7ea28472b626681154ab222623`, then run:

```sh
make test-integration
```

The verification step fails before running tests if the checkout is missing, is at
the wrong revision, or does not contain the tagged `docs/modding.md`. Integration
tests will be added only as public Mod API 2 entry points are verified; they must
not import or include private engine modules.
