# Golden-file reference for `mathc attest-batch`.
#
# These three JSONs are byte-equivalent (modulo `issued_at`, which is
# wall-clock-dependent at runtime) to what `mathc attest-batch` writes
# for the three rows in `manifest.tsv`. They are committed so a future
# contributor can:
#
#   1. Run the binary against the manifest and capture its output.
#   2. Diff against these golden files (ignoring `issued_at` and `id`).
#   3. Spot a regression in canonical-JSON ordering, key names, or
#      default values.
#
# The cram fixture `tests/cli/attest-batch-positive.t` does NOT depend
# on these goldens; it recomputes `id` dynamically via Python
# (`hashlib.sha256` of the canonical body) and asserts equality. The
# goldens are for human inspection only — see
# `bin/data/manifest.example.tsv` for the matching input.
#
# Re-generating the goldens (e.g. after a canonical-JSON format bump):
#
#   python3 - <<'EOF'
#   import hashlib, json
#   rows = [
#     ('d1-onboarding','d1-obl-acceptance','review','human:integration-experiment','pass'),
#     ('d1-onboarding','d1-obl-noise',     'review','human:integration-experiment','pass'),
#     ('d2-rollout',   'd2-obl-build',     'test',  'ci:fixture:rollout-bot',     'pass'),
#   ]
#   ISSUED_AT = '2026-10-16T06:00:00Z'   # any stable sentinel
#   for d, o, k, p, r in rows:
#     att = {'schema':'math-coding/attestation-3.3','kind':'attestation',
#            'subject':{'decision':d,'obligation':o,'candidate_tree':'HEAD','materials_digest':''},
#            'kind_':k,'producer':{'identity':p},'result':r,'issued_at':ISSUED_AT}
#     body = {k: v for k, v in att.items() if k != 'id'}
#     payload = json.dumps(body, sort_keys=True, separators=(',', ':'), ensure_ascii=False).encode('utf-8')
#     att['id'] = 'sha256:' + hashlib.sha256(payload).hexdigest()
#     print(json.dumps(att, sort_keys=True, separators=(',', ':'), ensure_ascii=False))
#   EOF