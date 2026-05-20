# CI Pre-commit Caching — Implementation Checklist

**Goal:** Reduce `reusable-pre-commit.yml` runtime using the lowest-maintenance, highest-impact caching changes before introducing a container image.

**Current observation:** The passing dogfood run took about 2m26s. The expensive steps were not the changed-file hooks themselves; they were setup and one-time repo initialization work.

---

## 1. Remove avoidable one-time work from normal CI runs

- [ ] Confirm downstream repos commit `.secrets.baseline` as part of rollout so CI rarely needs to generate one
- [ ] Keep the CI fallback that creates `.secrets.baseline` only when it is genuinely missing
- [ ] After first rollout PRs land, verify the `Create .secrets.baseline if not present` step is near-zero on normal runs

---

## 2. Cache pre-commit hook environments

- [x] Add an `actions/cache` step for `~/.cache/pre-commit`
- [x] Key the cache from:
  - OS
  - Python version
  - selected profile string
  - hash of `.pre-commit-config.ci.yaml`
- [x] Add a restore key prefix so minor profile changes can still reuse older hook environments
- [x] Place the cache restore before `pre-commit run ...`
- [ ] Validate a second run shows a cache hit and reduced hook setup time

**Why first:** this is usually the easiest and highest-impact cache for pre-commit-based workflows because hook environments are expensive to rebuild and safe to reuse when the generated config is unchanged.

---

## 3. Cache pip downloads used by the bootstrap step

- [x] Enable pip caching in `actions/setup-python` or add an explicit cache for the pip download directory
- [x] Confirm the cache key is tied to Python version and dependency inputs derived from the selected profiles
- [ ] Measure whether `Install pre-commit and profile dependencies` drops on a second run

**Why second:** lower impact than pre-commit environment reuse, but still cheap to maintain.

---

## 4. Re-measure before adding more complexity

- [x] Capture runtime before caching
- [x] Capture first run after caching is added
- [ ] Capture second run with warm caches
- [ ] Decide whether the remaining runtime is acceptable without a container image

**Decision rule:** if caching keeps normal runs comfortably near the current 2-minute range, stop here and avoid container maintenance.

---

## 5. Optional follow-up caches only if still needed

- [ ] Evaluate Ruby gem caching only if `ruby` profile runs become a meaningful share of total runtime
- [ ] Evaluate Node package caching only if `node` profile runs show repeated setup cost that pre-commit cache does not already absorb
- [ ] Revisit the container option only if repeated measurements show caching is insufficient

**Why optional:** these add more maintenance and should only be introduced if the measured bottleneck remains in those toolchains.

---

## 6. Validation

- [ ] Verify cache hits appear in Actions logs
- [ ] Verify cache misses still produce a correct green run
- [ ] Verify changed-files behavior is unchanged
- [ ] Verify initial-push and missing-ref fallback paths still work

---

## Expected outcome

- [ ] Normal repeat runs avoid rebuilding hook environments
- [ ] CI remains simpler than the container-based alternative
- [ ] Containerization stays deferred unless measured data justifies it
