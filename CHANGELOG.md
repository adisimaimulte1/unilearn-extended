# Changelog

All notable changes to **Unilearn** are documented here.

The project was developed through frequent feature pushes rather than formal version tags. Related commits are therefore grouped below into clean chronological milestones, using exact dates where a milestone maps clearly to a push and date ranges where an update was built across several commits.

---

## Initial Project Foundation — 04.05.2026

### Added
- Created the first Unilearn project structure in Godot.
- Established Android as the main target platform.
- Added the first space-themed scenes, assets, interface elements, and project resources.
- Added the initial celestial-body visuals and interaction foundations.
- Introduced the core idea of an interactive universe that combines simulation, exploration, and learning.

---

## Android Project Setup — 04.05.2026

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

## Main Menu, Settings, and Space Navigation — 10.05.2026

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

## Configurable AI System — 11.05.2026

### Added
- Added Apollo, Unilearn’s configurable AI assistant.
- Added reusable command and response configuration.
- Added assistant states for listening, thinking, speaking, and idle behavior.
- Added support for locally mapped actions and generated responses and backend server fallback.
- Added the foundation for voice-controlled navigation and gameplay.

### Improved
- Separated AI behavior from the interface so commands could be expanded more easily.
- Improved response handling and assistant feedback.

---

## Voice-Controlled Settings — 12.05.2026

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

## Galaxy Configuration and Simulator Controls — 13.05.2026

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

## AI Planet Card Generation — 14.05.2026

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

## Planet Card Collection and Progression — 15.05.2026

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

## Planet Quiz — 16.05.2026

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

## Player–Planet Interaction — 17.05.2026

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

## Advanced Galaxy Simulation — 20.05.2026

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

## Achievements — Initial Release — 30.05.2026

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

## Achievement Expansion and General Polish — 20.06.2026

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

## Documentation and Repository Presentation — 21.06.2026

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

## ApolloSpeechPlugin Update — 03.07.2026

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

## Apollo AI Expansion — 03.07.2026

### Added
- Added more navigation and simulator commands.
- Added local fallback responses for unsupported or unsuccessful actions.
- Added special responses when the user is already in the requested location.
- Added special responses when a requested setting is already active.
- Added linked-command support.
- Added more assistant animation and state feedback.
- Added generated Planet Card and quiz interactions to Apollo’s command set.

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

## AI Assistant Achievements — 04.07.2026

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

## Performance Update — 05.07.2026

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

## Multiplayer — Initial Foundation — 05.07.2026

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

## Multiplayer Requests and Interface — 06.07.2026

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

## Commercial and Release Preparation — 08.07.2026

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

## Multiplayer UI Completion — 10.07.2026

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
- Improved consistency with the rest of Unilearn’s popup and notification system.

---

## BLE Peer-to-Peer Multiplayer — 11.07.2026

### Added
- Added direct nearby-device communication through Bluetooth Low Energy.
- Added the custom native Android plugin **`UnilearnBlePlugin`**.
- Added BLE advertising.
- Added BLE scanning.
- Added peer discovery between real Android devices.
- Added Android Nearby Devices runtime permission handling.
- Added communication between Godot and the native BLE plugin.
- Added Firebase UID exchange for identifying nearby players.
- Added Firebase display-name lookup after receiving another player’s UID.

### Changed
- Replaced the earlier location-oriented discovery approach with actual device proximity through BLE.
- Simplified BLE advertisements so they broadcast only the player’s Firebase UID.
- Moved Bluetooth functionality into a dedicated reusable native Android plugin.
- Prepared multiplayer communication to work directly between nearby devices instead of using location as a proximity approximation.

### Improved
- Reduced the amount of data transmitted through BLE advertisements.
- Improved privacy by avoiding display-name broadcasting.
- Improved identity consistency by resolving player information through Firebase.
- Improved the multiplayer foundation for direct universe synchronization and Planet Card trading.

---

## Planet Card Trading — 11.07.2026

### Added
- Added complete Planet Card trading between nearby players.
- Added synchronized card-selection and confirmation screens.
- Added separate views for the local player’s card and the other player’s card.
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

## Shared Universe Synchronization — 12.07.2026

### Added
- Added shared universe sessions between two nearby players.
- Added synchronized celestial-body creation and removal.
- Added synchronization for Galaxy Console settings and behavior toggles.
- Added immediate visual refresh of open Galaxy Console controls when the other player changes a setting.
- Added immediate refresh of an open Planet Card details page when that card is remotely added to or removed from the galaxy.
- Added temporary snapshots of each player’s original universe and simulator settings.
- Added automatic restoration of each player’s original universe when synchronization ends.
- Added synchronized entry and exit barriers so both devices finish their transitions before the shared session changes state.

### Changed
- Kept physics, dragging, throwing, collisions, orbits, and body movement local to each device.
- Limited network synchronization to discrete body additions, body removals, and Galaxy Console setting changes.
- Removed continuous full-system position and velocity replication.
- Removed remote body-ownership locks and ownership indicators.
- Prevented the temporary synchronized universe from overwriting the player’s saved personal universe.

### Improved
- Greatly reduced multiplayer lag and movement stuttering.
- Improved simulator responsiveness during synchronized sessions.
- Improved remote slider and toggle updates by reusing Apollo’s existing live interface-animation paths.
- Improved synchronization reliability by extending the existing multiplayer event transport instead of creating an additional polling system.
- Improved universe-sync entry by playing the normal planet disappearance animation while both players return home.
- Improved universe-sync exit by fading out synchronized planets before restoring the original universe.
- Added the normal staggered planet load-in animation when the original universe is restored.
- Blocked interaction only for the duration of the entry and exit transitions.

### Fixed
- Fixed synchronized sessions clearing and saving over the player’s original universe.
- Fixed open Galaxy Console controls not reflecting remote changes.
- Fixed open Planet Card details pages showing an outdated add/remove button state.
- Fixed shared physics replication causing severe lag, visible corrections, and inconsistent interaction.
- Fixed abrupt planet removal and restoration when entering or leaving a synchronized universe.

---

## Final Multiplayer Polish and Project Completion — 12.07.2026

### Improved
- Completed the full nearby multiplayer flow from BLE discovery to requests, Planet Card trading, and shared universe sessions.
- Unified multiplayer animations, sounds, loading states, cancellation behavior, and restoration behavior with the rest of the application.
- Preserved each player’s local progress and simulator state across temporary multiplayer sessions.
- Completed the final interface synchronization and transition polish for the release build.

### Release Status
- Completed the planned feature set for the InfoEducație version of Unilearn.
- Finalized the application as a complete interactive universe simulator, educational game, AI-assisted experience, collectible-card system, achievement platform, and nearby multiplayer application.
