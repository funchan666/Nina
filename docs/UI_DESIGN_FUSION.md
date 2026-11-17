# Nina UI design

Nina is an iPhone app for adult skaters to browse lines, remember spots and compare practice between visits. The bundled HTML community presents registration, email login and the skate feed. Its Lines, Sessions and Crew destinations open the React Native gallery, practice notebook and spot-based skater directory. Both surfaces follow the same TypeScript journal state and read the same bundled collection. The iOS host provides Apple sign-in, camera, media layers and WKWebView.

The design uses skate-zine print, bone paper, evergreen ink and acid grip. The repeated visual from skateboarding is the line itself. A selected clip can become the reference for a trick plan and the same park can be reopened through the journal and Crew. No simulated social activity is used for composition.

| Decision | Value | Application |
| --- | ---: | --- |
| Visual variance | 7 | Full-width Lines feature, practice notebook and dense Crew directory use different rhythms. |
| Motion intensity | 2 | Presses and progress respond immediately. There are no decorative transitions or auto-playing videos. |
| Information density | 5 | Feature content is followed by a clip strip and a compact image index. Forms reveal relevant fields by action. |
| Asset dependence | 8 | Real content is distinct from generated page grounds, the wheel brand mark and functional sprites. |
| Brand fidelity | 2 | New identity follows the material culture of decks, bowls and paper session logs. |

Paper #F5F0E5, ink #182620, grip #DFF075, sage #DDE4D5 and oxide #A44731. Cyberpunk intensity 0/50. Barlow Condensed Bold carries headings, Barlow carries body and actions. Horizontal padding adapts with the window. Text stays dynamic. Full-bleed art is hit-test disabled. Elevation comes from ink/paper tone, with solid high-contrast form surfaces.

- ui-design-reference and ui-taste apply to composition, iOS controls, states and readable typography.
- design-taste-frontend informs hierarchy and avoiding repeated feature tiles. claude-design supplies the Explore/Operate distinction and the visual contract. Garden web-design-engineer supplies the five dials and asset prioritization. The media and journal screens use native React Native views.
- Garden gpt-image-2 and imagegen use the built-in Host-Native tool. Exact prompts and selected originals are in assets/brand and assets/navigation. The direction board is a visual reference.
- Duo uses the installed iPhoneOS 27.1 SDK, iOS 17.6 deployment, safe-area updates and active UIKit reserved regions for custom action bands. Safe-area and window-size updates provide the layout on earlier iOS releases. Layout follows container geometry and keeps navigation, edit and playback state outside geometry. Physical posture, keyboard, larger text and camera transitions remain to be exercised on device.

See [the visual implementation map](VISUAL_IMPLEMENTATION_SPEC.md) and [the asset plan](../assets/brand/original-asset-plan.json).
