# Changelog

All notable changes to **Unilearn** are documented here.

The project was developed through frequent feature pushes rather than formal version tags. Related commits are therefore grouped below into clean chronological milestones, using exact dates where a milestone maps clearly to a push and date ranges where an update was built across several commits.

---

## Initial Project Foundation â€” 04.05.2026

### Added
- Created the first Unilearn project structure in Godot.
- Established Android as the main target platform.
- Added the first space-themed scenes, assets, interface elements, and project resources.
- Added the initial celestial-body visuals and interaction foundations.
- Introduced the core idea of an interactive universe that combines simulation, exploration, and learning.

---

## Android Project Setup â€” 04.05.2026

### Added
- Added the Android project and export folders.
- Configured the project for Android builds.
- Added the initial native Android integration structure.
- Added advanced icon support and splash screen.
- Prepared the project for custom Android plugins and platform-specific features.

### Changed
- Reorganized the early project files into a structure better suited for Android development.
- Improved separation between game code, native functionality, assets, and configuration files.

---

## Main Menu, Settings, and Space Navigation â€” 10.05.2026

### Added
- Added the main menu.
- Added application settings.
- Added navigation between the main areas of the app.
- Added interactive planets and space navigation.
- Added the first complete version of the mobile interface.
- Added visual transitions, sounds, and space-themed navigation feedback.

### Improved
- Refined touch input and mobile layout behavior.
- Improved navigation consistency between screens.
- Expanded the project from a technical prototype into a usable application.

---

## Configurable AI System â€” 11.05.2026

### Added
- Added Apollo, Unilearnâ€™s configurable AI assistant.
- Added reusable command and response configuration.
- Added assistant states for listening, thinking, speaking, and idle behavior.
- Added support for locally mapped actions and generated responses and backend server fallback.
- Added the foundation for voice-controlled navigation and gameplay.

### Improved
- Separated AI behavior from the interface so commands could be expanded more easily.
- Improved response handling and assistant feedback.

---

## Voice-Controlled Settings â€” 12.05.2026

### Added
- Added voice commands for application settings.
- Added speech-based control for sound, visual settings, and other toggles.
- Added Android microphone permission handling.
- Added feedback for successful, failed, and already-completed commands.
- Added multiple spoken response variants for supported actions.

### Improved
- Improved command matching for common speech-recognition mistakes.
- Added support for requests containing more than one action.
- Prevented unnecessary changes when a setting already matched the request.

---

## Galaxy Configuration and Simulator Controls â€” 13.05.2026

### Added
- Added the Galaxy Console and configuration interface.
- Added simulator data, behavior, quick-command, and results sections.
- Added controls for gravity, trails, simulation speed, orbit behavior, and camera movement.
- Added active-body information and simulation analysis.
- Added configurable galaxy behavior directly from the interface.

### Improved
- Improved consistency between simulator settings and their visual controls.
- Added smoother sliders, camera resets, and immediate setting updates.
- Improved the connection between Apollo commands and simulator actions.

---

## AI Planet Card Generation â€” 14.05.2026

### Added
- Added AI-generated Planet Cards.
- Added generated names, subtitles, descriptions, scientific information, and visual identities.
- Added cards for planets, moons, stars, black holes, white holes, and other cosmic objects.
- Added generated learning prompts and structured object data.
- Added Firebase storage and synchronization for generated cards.
- Added card limits and generation-state feedback.
- Added Apollo voice commands for generating cards.

### Improved
- Optimized Planet Card generation and rendering performance.
- Improved validation of AI-generated card data.
- Added safer defaults for incomplete generated responses.
- Improved generated-object classification and visual selection.
- Reduced unnecessary processing during card creation and loading.

---

## Planet Card Collection and Progression â€” 15.05.2026

### Added
- Added the full Planet Card collection interface.
- Added card previews and detailed card pages.
- Added card search.
- Added card levels, XP, progression, statistics, and attribute badges.
- Added generated visual previews for different cosmic-object types.
- Added support for adding collected cards to the Galaxy Simulator.
- Added card progression synchronization with the backend.

### Improved
- Improved preview scaling for planets, moons, stars, and singularities.
- Improved card layout across different screen sizes.
- Improved hero animations and card-detail transitions.
- Improved search matching and result ordering.
- Improved loading and scrolling performance for larger collections.
- Added clearer feedback when the maximum number of cards is reached.

### Fixed
- Fixed Planet Card layout issues.
- Fixed preview clipping and rounded-corner artifacts.
- Fixed incorrect scaling for certain object types.
- Fixed card-detail input and animation regressions.
- Fixed multiple generated-card edge cases.

---

## Planet Quiz â€” 16.05.2026

### Added
- Added quizzes based on collected Planet Cards.
- Added generated questions and answers based on card data.
- Added quiz progression and result feedback.
- Added Apollo integration for starting and controlling quizzes.
- Added backend support for quiz generation.

### Improved
- Improved question validation and answer handling.
- Improved transitions between quiz states.
- Improved feedback for correct and incorrect answers.

---

## Playerâ€“Planet Interaction â€” 17.05.2026

### Added
- Added direct touch interaction with celestial bodies.
- Added dragging and throwing behavior.
- Added responsive planet movement based on player input.
- Added camera-relative interaction behavior.
- Added visual and sound feedback for direct manipulation.

### Improved
- Improved input translation between interface layers and simulator objects.
- Improved drag responsiveness and touch capture.
- Improved interaction when popups or detail views are open.
- Reduced conflicts between scrolling, tapping, holding, and dragging.

---

## Advanced Galaxy Simulation â€” 20.05.2026

### Added
- Added stable orbit creation.
- Added moon, planet, star, brown dwarf, white dwarf, black hole, and white hole behavior.
- Added celestial-body collisions and evolutionary transformations.
- Added satellites and parent-body relationships.
- Added binary systems.
- Added anchor-body behavior.
- Added black-hole attraction and white-hole repulsion.
- Added accretion-disk states.
- Added collision chains and special transformation events.
- Added trails and large-scale simulation effects.
- Added special end-of-universe sequences.

### Improved
- Improved orbit initialization and tangential velocity calculations.
- Improved collision detection and collision-result selection.
- Improved simulator stability at higher speeds.
- Improved behavior when several bodies collide in quick succession.
- Improved black-hole and white-hole interactions.
- Improved visual replacement when a body evolves into another type.
- Improved camera controls and barycenter framing.

### Fixed
- Fixed evolved objects retaining an outdated visual.
- Fixed invalid physics calls and freed-object references.
- Fixed several orbit, collision, and hierarchy edge cases.
- Fixed simulator input being blocked by interface elements.
- Fixed trails flickering or appearing dotted at different zoom levels.

---

## Achievements â€” Initial Release â€” 30.05.2026

### Added
- Added the achievement system.
- Added achievement categories for major simulator and progression activities.
- Added normal and rare achievements.
- Added Bronze, Silver, and Gold stages.
- Added hidden achievement information until the first stage is unlocked.
- Added achievement progress tracking.
- Added Firebase synchronization.
- Added unlock notifications, sounds, animations, and special rare-achievement presentation.

### Improved
- Added category-based achievement navigation.
- Added achievement checks for:
  - Adding celestial bodies.
  - Planet collisions.
  - Star collisions.
  - Black holes and white holes.
  - Simulation results.
  - Planet Card progression.
  - Special cosmic events.
- Improved popup transitions, scrolling, and category loading.
- Prevented previously unlocked achievements from being shown repeatedly.

---

## Achievement Expansion and General Polish â€” 20.06.2026

### Added
- Expanded the achievement catalog to a complete multi-category system.
- Added more event-specific and hidden achievements.
- Added checks for rare transformations and unusual simulation states.
- Added progression checks that work without requiring the related interface tab to be open.
- Added additional unlock sounds and feedback.

### Improved
- Improved achievement persistence and stage calculations.
- Improved popup loading and navigation.
- Improved category presentation and empty states.
- Improved achievement checks during complex collision sequences.
- Improved interaction between achievements, cards, Apollo, and the simulator.

### Fixed
- Fixed duplicate achievement sounds.
- Fixed achievement checks being triggered at the wrong time.
- Fixed removed or deprecated achievement categories continuing to update.
- Fixed several popup and back-button issues.

---

## Documentation and Repository Presentation â€” 21.06.2026

### Added
- Added a complete project README.
- Added feature, gameplay, platform, technology, and project-structure sections.
- Added installation and source-running instructions.
- Added project documentation links.
- Added repository badges and visual branding.
- Added licensing and maintainer information.

### Improved
- Reworked the README several times as the project expanded.
- Updated the documented feature list to include Planet Cards, Apollo, achievements, Firebase, the Galaxy Simulator, and multiplayer.
- Improved the repository folder structure and public presentation.

---

## ApolloSpeechPlugin Update â€” 03.07.2026

### Added
- Expanded the custom Android speech plugin.
- Added improved speech-recognition lifecycle handling.
- Added better permission and cancellation behavior.
- Added support for more reliable Godot-to-Android communication.
- Added more flexible command-result delivery to the game.

### Improved
- Improved handling of partial and final speech results.
- Improved microphone-state synchronization.
- Improved plugin stability across repeated listening sessions.
- Improved recovery from recognition errors.
- Improved command normalization for incorrectly recognized words.

---

## Apollo AI Expansion â€” 03.07.2026

### Added
- Added more navigation and simulator commands.
- Added local fallback responses for unsupported or unsuccessful actions.
- Added special responses when the user is already in the requested location.
- Added special responses when a requested setting is already active.
- Added linked-command support.
- Added more assistant animation and state feedback.
- Added generated Planet Card and quiz interactions to Apolloâ€™s command set.

### Changed
- Expanded Apollo from a settings assistant into a complete in-game control system.
- Reduced dependence on server fallback for commands that could be understood locally.
- Moved more command recognition and correction logic into the application and Android plugin.

### Improved
- Improved multi-command parsing.
- Improved fuzzy matching for speech-to-text mistakes.
- Improved UI locking while Apollo performs navigation.
- Improved assistant color and opacity behavior across themes.

---

## AI Assistant Achievements â€” 04.07.2026

### Added
- Added the AI Assistant achievement category.
- Added achievements for using Apollo commands.
- Added achievements for linked commands.
- Added achievements for generated cards and quizzes.
- Added normal and rare Apollo-related achievements.
- Added backend and frontend tracking for AI Assistant progression.

### Changed
- Removed the former Stable Systems achievement category.
- Removed old Stable Systems checks from the frontend and backend.
- Replaced the removed category with AI Assistant progression.

---

## Performance Update â€” 05.07.2026

### Improved
- Improved startup and interface performance.
- Reduced unnecessary node creation.
- Improved Planet Card and achievement loading.
- Improved caching and reuse of interface elements.
- Optimized star previews with MultiMesh rendering.
- Reduced star preview instance counts while preserving the visual effect.
- Improved simulator trail updates.
- Reduced repeated work during popup refreshes.
- Improved Firebase synchronization timing.

### Fixed
- Fixed several first-open stalls.
- Fixed repeated list animations after refreshes.
- Fixed delayed theme updates.
- Fixed unnecessary loading during the splash screen.
- Fixed interface elements rebuilding more often than required.

---

## Multiplayer â€” Initial Foundation â€” 05.07.2026

### Added
- Added the Multiplayer section.
- Replaced the former help entry with multiplayer access.
- Added a multiplayer profile name.
- Added Firebase-backed `displayName` support.
- Added a location-based nearby-player toggle.
- Added permission handling for nearby-player discovery.
- Added nearby-player list states and searching feedback.
- Added the foundation for:
  - Universe synchronization.
  - Planet Card trading.

### Improved
- Added local caching for the multiplayer display name.
- Added backend synchronization when the name changes.
- Added clear states for disabled permissions, searching, and no nearby players.
- Added theme-aware multiplayer interface elements.

---

## Multiplayer Requests and Interface â€” 06.07.2026

### Added
- Added swipe-based multiplayer actions.
- Added separate actions for universe synchronization and Planet Card trading.
- Added request sending, acceptance, denial, cancellation, and timeout states.
- Added request cards and notifications.
- Added animated waiting indicators.
- Added sender and receiver feedback.
- Added blocking while a request is pending.
- Added automatic cleanup when requests expire.
- Added multiplayer request sounds and animations.

### Improved
- Improved swipe thresholds and gesture feedback.
- Improved touch capture and popup interaction.
- Improved request-card positioning and scaling.
- Improved animations when requests enter and leave.
- Improved theme changes so multiplayer UI updates immediately.
- Prevented nearby-player refreshes from replaying opening animations.
- Prevented duplicate requests and duplicate notifications.
- Improved behavior when the multiplayer popup is closed during an active request.
- Improved navigation back to the simulator after a multiplayer response.

### Fixed
- Fixed request notifications occasionally appearing without icons.
- Fixed delayed highlighted-text color updates.
- Fixed list height and scroll animation resets.
- Fixed request cards intercepting or passing through touches incorrectly.
- Fixed repeated sounds and inconsistent timeout behavior.

---

## Commercial and Release Preparation â€” 08.07.2026

### Changed
- Updated the project license and release-facing documentation.
- Prepared the project structure for public distribution.
- Improved explanations of backend, Firebase, and AI operating costs.
- Refined the README and feature presentation.
- Cleaned up unused user-profile fields and backend data.
- Prepared Apollo to rely less on paid server fallback after the competition build.

### Improved
- Improved repository organization.
- Improved release documentation.
- Improved project branding and public presentation.
- Improved the separation between competition functionality and future commercial operation.

---

## Multiplayer UI Completion â€” 10.07.2026

### Added
- Completed the nearby-player interface.
- Added final swipe-card visuals.
- Added polished request toasts.
- Added multiplayer information to the project documentation.
- Added final empty-state, loading-state, and permission-state presentation.

### Improved
- Refined spacing, borders, corner radii, icon sizes, and card positioning.
- Improved request animation timing.
- Improved player-list refresh behavior.
- Improved name editing and character limits.
- Improved consistency with the rest of Unilearnâ€™s popup and notification system.

---

## BLE Peer-to-Peer Multiplayer â€” 11.07.2026

### Added
- Added direct nearby-device communication through Bluetooth Low Energy.
- Added the custom native Android plugin **`UnilearnBlePlugin`**.
- Added BLE advertising.
- Added BLE scanning.
- Added peer discovery between real Android devices.
- Added Android Nearby Devices runtime permission handling.
- Added communication between Godot and the native BLE plugin.
- Added Firebase UID exchange for identifying nearby players.
- Added Firebase display-name lookup after receiving another playerâ€™s UID.

### Changed
- Replaced the earlier location-oriented discovery approach with actual device proximity through BLE.
- Simplified BLE advertisements so they broadcast only the playerâ€™s Firebase UID.
- Moved Bluetooth functionality into a dedicated reusable native Android plugin.
- Prepared multiplayer communication to work directly between nearby devices instead of using location as a proximity approximation.

### Improved
- Reduced the amount of data transmitted through BLE advertisements.
- Improved privacy by avoiding display-name broadcasting.
- Improved identity consistency by resolving player information through Firebase.
- Improved the multiplayer foundation for direct universe synchronization and Planet Card trading.

---

## Planet Card Trading â€” 11.07.2026

### Added
- Added complete Planet Card trading between nearby players.
- Added synchronized card-selection and confirmation screens.
- Added separate views for the local playerâ€™s card and the other playerâ€™s card.
- Added live updates when either player selects or changes a card.
- Added trade expiration handling and synchronized cancellation.
- Added synchronized readiness checks so the exchange begins only after both devices have loaded the selected cards.
- Added a complete card-exchange animation with outgoing and received-card presentation.
- Added support for transferring the full generated Planet Card data between players.
- Added local collection updates after a successful trade.
- Added backend updates that remove the sent card and save the received card.
- Added automatic removal of a traded card from the active galaxy when necessary.

### Improved
- Improved synchronization timing between the player who selects first and the player who selects second.
- Improved loading subtitles and waiting states.
- Improved unknown-card sizing and visual consistency.
- Improved card scaling, fading, layering, and rounded-corner presentation during the exchange.
- Improved touch blocking and hold cancellation before the trade animation begins.
- Improved trade reset behavior so previous cards do not remain visible during a later exchange.
- Improved repeated-trade reliability and reduced unnecessary backend polling.

### Fixed
- Fixed duplicated card rectangles and interface elements.
- Fixed stale cards appearing during a second trade.
- Fixed nil-node position errors during card loading.
- Fixed the second player entering the exchange animation without the required delay.
- Fixed faded interface elements remaining visible behind the received card.
- Fixed inconsistent hero-image opacity during the trade animation.
- Fixed multiple synchronization and timing edge cases.

---

## Shared Universe Synchronization â€” 12.07.2026

### Added
- Added shared universe sessions between two nearby players.
- Added synchronized celestial-body creation and removal.
- Added synchronization for Galaxy Console settings and behavior toggles.
- Added immediate visual refresh of open Galaxy Console controls when the other player changes a setting.
- Added immediate refresh of an open Planet Card details page when that card is remotely added to or removed from the galaxy.
- Added temporary snapshots of each playerâ€™s original universe and simulator settings.
- Added automatic restoration of each playerâ€™s original universe when synchronization ends.
- Added synchronized entry and exit barriers so both devices finish their transitions before the shared session changes state.

### Changed
- Kept physics, dragging, throwing, collisions, orbits, and body movement local to each device.
- Limited network synchronization to discrete body additions, body removals, and Galaxy Console setting changes.
- Removed continuous full-system position and velocity replication.
- Removed remote body-ownership locks and ownership indicators.
- Prevented the temporary synchronized universe from overwriting the playerâ€™s saved personal universe.

### Improved
- Greatly reduced multiplayer lag and movement stuttering.
- Improved simulator responsiveness during synchronized sessions.
- Improved remote slider and toggle updates by reusing Apolloâ€™s existing live interface-animation paths.
- Improved synchronization reliability by extending the existing multiplayer event transport instead of creating an additional polling system.
- Improved universe-sync entry by playing the normal planet disappearance animation while both players return home.
- Improved universe-sync exit by fading out synchronized planets before restoring the original universe.
- Added the normal staggered planet load-in animation when the original universe is restored.
- Blocked interaction only for the duration of the entry and exit transitions.

### Fixed
- Fixed synchronized sessions clearing and saving over the playerâ€™s original universe.
- Fixed open Galaxy Console controls not reflecting remote changes.
- Fixed open Planet Card details pages showing an outdated add/remove button state.
- Fixed shared physics replication causing severe lag, visible corrections, and inconsistent interaction.
- Fixed abrupt planet removal and restoration when entering or leaving a synchronized universe.

---

## Final Multiplayer Polish and Project Completion â€” 12.07.2026

### Improved
- Completed the full nearby multiplayer flow from BLE discovery to requests, Planet Card trading, and shared universe sessions.
- Unified multiplayer animations, sounds, loading states, cancellation behavior, and restoration behavior with the rest of the application.
- Preserved each playerâ€™s local progress and simulator state across temporary multiplayer sessions.
- Completed the final interface synchronization and transition polish for the release build.

### Release Status
- Completed the planned feature set for the InfoEducaÈ›ie version of Unilearn.
- Finalized the application as a complete interactive universe simulator, educational game, AI-assisted experience, collectible-card system, achievement platform, and nearby multiplayer application.

---

## Offline Mode, Guided Tutorial, and Final Application Polish â€” 22.07.2026

### Added
- Added authenticated offline mode with account-specific local storage for the complete Planet Card collection, achievement progress, and unlocked achievements.
- Added native Android connectivity monitoring without server pings, DNS checks, or repeated HTTP requests.
- Added live online and offline interface states across the bottom menu, Settings, Multiplayer, Planet Cards, quizzes, and other backend-dependent features.
- Added automatic synchronization of locally earned achievement progress when connectivity returns.
- Added a dedicated **Singularity** Planet Card filter and separated black holes and related bodies from the normal Planet category.
- Added Planet Card and black-hole discovery achievement checks after successful trades.
- Added a polished hold-to-generate animation that progressively converts the Planet Card border and name box into the current highlighted-text color.
- Added a complete Apollo-led onboarding tutorial explaining voice commands, navigation, Planet Cards, search, filters, AI generation, card statistics and games, the Galaxy Simulator, Galaxy Console, and achievements.
- Added expanded in-app feature documentation covering the applicationâ€™s main systems and advanced interactions.
- Added locally saved tutorial completion and replay support so onboarding remains available without internet access.
- Added the local Apollo command **â€œHow to use the app?â€**, including natural speech variants such as **â€œHow to play the game?â€**, which returns the interface home and immediately replays the guided tutorial without requiring a backend response.
- Added a transformed account-deletion confirmation view inside Settings, including animated height changes, safe cancellation, offline protection, and consistent button feedback.

### Changed
- Changed offline interface elements to Apolloâ€™s inactive gray (`#B8B8B8`) at 35% opacity, with smooth transitions when connectivity changes.
- Disabled online-only actions while offline, including Planet Card generation, quizzes, Multiplayer discovery, logout, and account deletion.
- Replaced unavailable online states with clear **NO INTERNET** feedback and restored all labels, colors, controls, and backend behavior automatically after reconnecting.
- Excluded white holes from Planet Card trading.
- Kept the active trading partner visible as the only nearby player during an exchange and displayed the **CARD TRADE** status.
- Required AI-generated measurement fields to contain clean numerical values and exactly one unit.
- Required every generated Planet Card to contain a valid preset, hero type, color palette, and complete visual configuration; invalid responses now return an error instead of creating a broken card.

### Improved
- Improved collision-created black-hole sizing, hitboxes, held-body behavior, visual replacement, mass-based survivor selection, and accretion-disk inheritance.
- Ensured black-hole collision results remain at least as large as the largest participating black hole while keeping survival logic based on mass.
- Improved Planet Card search layouts so a single result keeps the normal card size.
- Improved trade animation scaling, hero clipping, star backgrounds, accretion disks, borders, layering, and rounded-corner consistency.
- Matched animated trade cards to the clipping and proportions of normal card previews.
- Improved Planet Card and Achievement list animations so elements never scale beyond their normal size.
- Improved visual consistency of gradients and themed colors across different Android displays.
- Made the hold-to-generate effect reversible, theme-sensitive, resumable, and isolated from the Planet Card trade popup.
- Preserved the completed hold appearance throughout rendering and restored the card to white with a final completion animation.
- Improved offline performance by stopping multiplayer, achievement, and backend retry loops immediately after connectivity is lost.
- Improved reconnect behavior by merging and uploading offline achievement progress once instead of sending repeated individual requests.
- Improved tutorial timing so Apolloâ€™s narration remains synchronized with menu navigation, Planet Card filtering and generation, card-detail scrolling, simulator placement, Galaxy Console controls, and Achievement exploration.
- Improved tutorial popup proportions, title hierarchy, subtitle spacing, vertical balance, button behavior, input blocking, transitions, and sound effects to match the rest of the application.
- Improved tutorial replay so Apollo remains in the Thinking state while returning home, then changes to Speaking only when the local tutorial narration begins.
- Improved account login and registration feedback with clean white status messages while preserving the original interface styling.

### Fixed
- Fixed duplicated gravity units and descriptive text appearing in numerical measurement fields.
- Fixed generated cards occasionally missing a usable UI preset or visual identity.
- Fixed black-hole presets being incorrectly filtered as planets.
- Fixed collision-created black holes changing appearance without updating their size.
- Fixed visually larger black holes appearing to survive while a different mass-dominant body survived internally.
- Fixed held touches remaining attached outside a collision-grown bodyâ€™s new hitbox.
- Fixed missing Planet Cards popup setup calls and Achievement autoload warnings.
- Fixed nearby-player lists becoming empty after a trade was accepted.
- Fixed heroes, stars, accretion disks, and backgrounds rendering over card borders or outside rounded corners during trade animations.
- Fixed white pixels, mismatched corner radii, and border snapping during Planet Card hold animations.
- Fixed taps, detail views, theme changes, and additional holds incorrectly resetting an active rendering state.
- Fixed repeated `connect_to_host` debugger errors and unnecessary backend traffic while offline.
- Fixed Android connectivity validation incorrectly keeping some connected devices in offline mode.
- Fixed the Multiplayer location label rapidly alternating between enabled and searching states when Bluetooth or internet access was unavailable.
- Fixed offline quiz attempts playing both click and error sounds; they now play only the error sound.
- Fixed tutorial input passing through to the simulation and other interface layers.
- Fixed tutorial popups having excessive height, uneven internal spacing, and inconsistent top and bottom padding.
- Fixed duplicate or incorrect sounds when opening popups, cancelling card generation, dismissing tutorial prompts, and cancelling account deletion.
- Fixed account-deletion confirmation controls expanding the original Settings popup width.
- Fixed account deletion remaining actionable after connectivity was lost; offline confirmation now plays an error sound and performs no action.
- Fixed tutorial replay attempting to use a normal Apollo response preset instead of launching the local guided narration directly.

### Release Status
- Completed authenticated offline support, the Apollo onboarding tutorial, and expanded in-app documentation.
- Completed the final generation, collision, trading, achievement, connectivity, animation, and cross-device visual polish pass.
- Finalized Unilearn as a competition-ready Android experience that remains useful offline and introduces every major feature directly inside the application.

---

## Galaxy Simulator Optimization and Stability - 24.07.2026

### Improved
- Greatly improved performance for complex systems containing up to 16 active bodies.
- Optimized Verlet integration, orbit-hierarchy caching, gravity-pair selection, collisions, moon calculations, and cached SubViewport rendering.
- Added smooth, adaptive anchor-first restoration of saved systems, with synchronized planet, Apollo, and bottom-menu entrance animations.
- Improved hierarchical moon orbits, binary interactions, and collision behavior without reducing visual quality or trail detail.

### Fixed
- Fixed repeated orbit-architecture rebuilding and other physics calculations that caused severe frame-rate drops.
- Fixed moons receiving incorrect protection after finding a host, unstable motion around moving parents, and first-frame teleporting while loading.
- Fixed merged stars incorrectly counting as several direct black-hole collisions.
- Fixed **The End of the Universe** notification appearing before the ending sequence completed.
