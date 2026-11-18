# Nina UI design

Nina is an iPhone app for adult skaters to browse lines, remember spots and compare practice between visits. The bundled HTML community presents registration, email login and the skate feed. Its Lines, Sessions and Crew destinations open the React Native gallery, practice notebook and spot-based skater directory. Both surfaces follow the same TypeScript journal state and read the same bundled collection. The iOS host provides Apple sign-in, camera, media layers and WKWebView.

The design uses skate-zine print, bone paper, evergreen ink and acid grip. The repeated visual from skateboarding is the line itself. A selected clip can become the reference for a trick plan and the same park can be reopened through the journal and Crew. No simulated social activity is used for composition.

| Decision | Value | Application |
| --- | ---: | --- |
| Visual variance | 7 | Full-width Lines feature, practice notebook and dense Crew directory use different rhythms. |
| Motion intensity | 2 | Presses and progress respond immediately. There are no decorative transitions or auto-playing videos. |
| Information density | 5 | Feature content is followed by a clip strip and a compact image index. Forms reveal relevant fields by action. |
| Asset dependence | 8 | Real content is distinct from generated page grounds and functional sprites. |
| Brand fidelity | 2 | New identity follows the material culture of decks, bowls and paper session logs. |

Paper #F5F0E5, ink #182620, grip #DFF075, sage #DDE4D5 and oxide #A44731. Cyberpunk intensity 0/50. Barlow Condensed Bold carries headings, Barlow carries body and actions. Horizontal padding adapts with the window. Text stays dynamic. Full-bleed art is hit-test disabled. Elevation comes from ink/paper tone, with solid high-contrast form surfaces.

- ui-design-reference and ui-taste apply to composition, iOS controls, states and readable typography.
- design-taste-frontend informs hierarchy and avoiding repeated feature tiles. claude-design supplies the Explore/Operate distinction and the visual contract. Garden web-design-engineer supplies the five dials and asset prioritization. The media and journal screens use native React Native views.
- Garden gpt-image-2 and imagegen use the built-in Host-Native tool. Exact prompts and selected originals are in assets/brand and assets/navigation. The direction board is a visual reference.
- Duo uses the installed iPhoneOS 27.1 SDK, iOS 17.6 deployment, safe-area updates and active UIKit reserved regions for custom action bands. Safe-area and window-size updates provide the layout on earlier iOS releases. Layout follows container geometry and keeps navigation, edit and playback state outside geometry. Physical posture, keyboard, larger text and camera transitions remain to be exercised on device.

See [the visual implementation map](VISUAL_IMPLEMENTATION_SPEC.md) and [the asset plan](../assets/brand/original-asset-plan.json).

## Welcome and full-screen layout · 2026-11-18

The welcome screen uses the original full-height WelcomeGround illustration and Barlow Condensed lettering. Its current illustration shows four adult friends gathered at a skatepark, sharing a clip and laughing together. Warm expressions, close body language, a shared phone and resting boards establish a social scene. Faces occupy the upper-middle of the image, with quiet evergreen foreground behind the live title and actions. The headline reads “See you at the spot.” Supporting copy reads “For the clips you replay and the friends you skate with.” Create profile and Sign in describe the two entry actions. Registration and email login share a separate compact form with visible field labels, a single primary submit action and inline policy links. Implementation descriptions about local storage and the current device have been removed from these controls and supporting paragraphs.

Impeccable Clarify and Humanizer guide the copy refinement. Email login says Welcome back, registration says Create your profile, and the switch between them names the destination. Clips, photos, spots and sessions retain consistent terms across the web and React Native screens. Media controls say Watch clip or View photo, and comments use Add comment when creating and Save comment when editing. Empty states distinguish an unused journal, an empty saved collection, a filter with no lines and a name search with no matches. Copy offers the available next action without claiming online matching, message delivery or a connected multiuser service.

Email entry now uses the same input validation for both access modes. A valid email and a nonempty password open the matching profile or create it on first use. Passwords are not checked against a stored credential or persisted. The former registration-only minimum-length hint is removed. Agreement, inline errors, submission locking and the genuine native Apple flow remain in place. This change does not alter container measurements, the mounted WebView or input continuity during resizing. Verification is static only.

The design preserves Nina's ink, paper and grip palette. Impeccable's local text workflow, UI Design Reference, UI Taste, Claude Design and Garden Web Design Engineer guide the composition and form hierarchy. Taste was evaluated for applicability. Its current marketing-page workflow excludes app screens, so it supplies no additional gates. Existing original artwork and functional glyphs are reused.

Every screen's outer container extends to the window edges. Community content receives host geometry through CSS variables while its WebView remains full-size. Headers, bottom actions and form text consume only the local protection they need. Media extends underneath its overlaid close control. The website and policy WebViews use the full-screen viewport setting inside the app.

Duo's window measurements and active reserved regions remain connected. Resizing updates layout values without reloading the community or rebuilding its account state. Responsive welcome and form layouts support a wider container, with scrollable content on short screens. Verification for this revision covers source syntax, resource references, archive contents and diffs. No app build, browser execution, simulator, keyboard interaction or physical Duo posture was run.

The in-app welcome, login, community, settings and loading surfaces use functional headings and controls. Repeated app icons and app-name labels have been removed, including the launch image. The welcome header disappears, the email form retains its back action, and the community toolbar retains sign out. The old logo's reserved space and bundled web copy are removed. Original brand artwork remains in the source asset collection.

Welcome actions use 56 CSS-pixel minimum heights, 18 CSS-pixel semibold labels and a 12 CSS-pixel gap. The primary action explicitly sets ink text on grip so it cannot inherit the welcome screen's paper text. Sign in uses a solid ink surface with a 2 CSS-pixel paper outline, and reverses to paper with ink text while pressed. Labels, hit areas and focus outlines remain independent of the background illustration. Contrast is checked from the declared color values. This refinement has no new runtime capture.

The login view includes Apple's native `ASAuthorizationAppleIDButton`, using its Sign in label and black style with a 10-point corner radius. It sits in the native action region immediately below the scrollable web form. Its size follows the current container, with a 52-point height and the existing action-band occlusion handling. Agreement state and web submission state control availability. Pressing it starts the existing system authorization flow directly. The web form remains mounted during authorization and cancellation. Static checks cover the state messages and references. Official documentation was checked for the native button, and real-device authorization remains unverified.

The updated welcome artwork was generated with the built-in image tool in the Garden Image 2 Host-Native workflow. The 860 × 1828 PNG master lives in `assets/brand/welcome-crew-hangout.png`. Its JPEG q88 runtime copy is 429,653 bytes, with the same dimensions. The exact prompt is recorded in `assets/brand/image-prompts.md`. The compressed image was visually inspected. Banner and wide-screen image positions use a 14% vertical focus to keep the friends' faces in view. App rendering and physical device cropping were not run.
