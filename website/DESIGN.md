# Nina website

The website is a skate-magazine spread with one original social campaign image. Its job is to introduce the iPhone journal, show its actual content and give readers clear access to the terms and privacy policy. There is no store URL yet, so the primary action opens the journal section rather than implying an available App Store download.

The homepage is a Decide / Learn surface. Policies are Read surfaces. Both use evergreen ink `#14221b`, paper `#F5F0E5`, grip `#DFF075` and sage `#CAD5C4`. Barlow Condensed Bold carries short, large headlines. Barlow carries the reading and interaction text. WOFF files are converted from the licensed project fonts; both OFL files stay in the deployment.

## Composition

The opening pairs “See you at the spot.” with a panoramic image of four fictional adult friends sharing a skate clip. The image is captioned as original Nina artwork. The Spot Book and trick-log explanation uses the existing original bowl print and a clearly labelled example entry. The collection has an asymmetric photo spread with real project media and Park, Street and Off the board filters. A native HTML disclosure list answers practical questions. An oversized Nina wordmark closes the page.

The signature motion is a brief settling movement on the opening image. Short section entrances and control feedback support it. Content is visible without JavaScript, the filters appear only after their listeners are attached, and reduced-motion preferences disable travel. Gallery changes announce the visible count and keep keyboard focus on the selected button. There is no autoplay, tracking, remote font or extra framework.

Policies retain their existing wording, dates, section anchors and URLs. A dark title field, grip contents navigation and paper reading column connect them to the homepage. The contents remain available at small widths. The app's fallback policies are generated from the same article and shared stylesheet. WOFF fonts are embedded in each fallback because the native file reader grants access only to that HTML file. The native read scope and project resource configuration are unchanged.

## Assets

| Website asset | Source | Treatment |
| --- | --- | --- |
| `assets/crew-session.jpg` | `assets/brand/website-crew-session.png` | Built-in image generation with the Garden Image 2 Host-Native workflow, JPEG q88, original dimensions, compressed image visually inspected. |
| `assets/blue-pool.jpg` | `web/community/media/lines-v1-park-blue-pool-carve.jpg` | Previously optimized, authorized project media, copied byte for byte. |
| `assets/crew-walk.jpg` | `web/community/media/lines-v1-offboard-park-path-crew.jpg` | Previously optimized, authorized project media, copied byte for byte. |
| `assets/street-deck.jpg` | `web/community/media/lines-v1-street-boards-at-the-steps.jpg` | Previously optimized, authorized project media, copied byte for byte. |
| `assets/bowl-print.jpg` | Existing original website artwork | Reused in the journal example. |

The campaign image prompt is in `assets/brand/image-prompts.md`, under `website-crew-session-2026-11-18`. Its master stays outside the app resources. The compressed campaign image is also reused by the authenticated Discover session entry in Nina.zip; the website-only gallery copies stay outside the app resource pack. The contact email remains omitted. No live members, message delivery, reviews, store availability or usage statistics are invented.

## Verification boundary

This revision uses source syntax, asset and anchor references, font measurements, legal-article parity, packaging and deployment checks. The new campaign image was inspected. App compilation, tests, browser execution, screenshots and device layout validation were not run.
