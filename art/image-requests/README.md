# Image-API requests (AD -> producer -> adapter)

The AD lane has no network and no keys. When it needs an image after Stage B (a supporting view,
turnaround, variation, reference edit, character sheet, extra prop in the approved look), it
writes one JSON file per request into `art/image-requests/pending/`. The producer runs
`~/openjar/lanes/image-api.py` between AD runs; results land in `art/image-requests/done/<id>/`
(images + `result.json` with model, seed, cost, sha256), the request file moves there too, and one
line is appended to `art/provenance/generation-jobs.jsonl`. Midjourney never appears here.

## Request schema (`pending/<id>.json`)
```json
{
  "id": "worm-master-side-001",
  "ticket": "art/tickets/T-003.md",
  "purpose": "side view of the approved worm master, neutral background, for the PixelLab reference",
  "model": "kontext-pro",
  "prompt": "Same worm, same colours and markings, seen exactly side-on, flat grey background",
  "reference_images": ["art/characters/worm/master-reference/master.png"],
  "n": 1,
  "aspect_ratio": "3:2",
  "seed": null,
  "max_usd": 0.10
}
```
- `model`: `kontext-pro` (default, $0.04/image, one reference image), `kontext-max` ($0.08/image,
  harder edits; multi-reference only if the producer has verified it), or `gpt-image` (OpenAI,
  token-priced, up to 16 reference images; producer enables it only if the owner approved it).
- `reference_images`: repo-relative paths only. Owner Midjourney images and our own files only;
  never a URL.
- `n`: 1 for any new kind of request (one unit first); up to 4 once that kind is proven.
- `max_usd`: the request is refused if its estimate is above this, or if it would take the pilot
  past its cap.

## Rules
- One request = one purpose = one ticket. Reference edits keep the approved identity; a change of
  identity, camera or technique is a Gate 3 exception, not a request.
- At most 3 attempts per asset (ticket `max_attempts`), then fail-escalate.
- Generated turnarounds are references, not geometry.
