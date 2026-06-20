<p align="center">
  <img src="https://i.ibb.co/GfHXQk6h/unilearn-github.png" alt="unilearn github" border="0" width="70%">
</p>

<p align="center">
  <img src="https://img.shields.io/static/v1?color=02040d&label=&logo=godotengine&logoColor=FFFFFF&message=Godot%204.6&style=for-the-badge" />
  <img src="https://img.shields.io/static/v1?color=02040d&label=&logo=android&logoColor=FFFFFF&message=Android%20Only&style=for-the-badge" />
  <img src="https://img.shields.io/static/v1?color=02040d&label=&logo=firebase&logoColor=FFFFFF&message=Firebase%20Powered&style=for-the-badge" />
  <img src="https://img.shields.io/static/v1?color=02040d&label=&logo=openai&logoColor=FFFFFF&message=AI%20Systems&style=for-the-badge" />
</p>

---

$\LARGE \color{#FFD166}{\textsf{DESCRIPTION}}$

**Unilearn** is an Android **space sandbox game** built in **Godot**, where the universe becomes something you can **play with, break, rebuild, and command**.

Create unstable systems, throw planets into orbit, collect cosmic cards, trigger black hole disasters, unlock achievements, and experiment with a galaxy that actually reacts.

This is not a static space app.  
It is a **playable universe**.

---

$\LARGE \color{#FFD166}{\textsf{STATUS}}$

**Unilearn is in active development.**

Public builds can be found in the **Releases** section of this GitHub repository.  
The project can also be opened from the `godot/` folder and tested locally on Android.

---

$\LARGE \color{#FFD166}{\textsf{CORE\ FEATURES}}$

• **Universe sandbox** with planets, moons, stars, black holes, white holes, and custom systems  
• **Galaxy Simulator** with stable orbits, collisions, trails, gravity behavior, and object evolution  
• **Planet Cards** with stats, levels, generated profiles, progression, and collectible-style presentation  
• **Achievements** for rare events, strange systems, collisions, transformations, and cosmic chaos  
• **Apollo AI** for in-game commands, generated cards, quizzes, and guided actions  
• **Universe Playground** for building, testing, destroying, and rebuilding cosmic setups  
• **Firebase sync** for accounts, saved progress, achievements, galaxies, and player data  
• **Android speech plugin** for voice interaction inside the game  
• **Pixel-style planets**, animated shaders, sound effects, and a high-contrast space UI  

---

$\LARGE \color{#FFD166}{\textsf{GAMEPLAY}}$

Unilearn is built around **experimentation**.

Players can build systems, add celestial bodies, watch them orbit, collide, evolve, collapse, or spiral into complete disaster. Every action is meant to feel direct, reactive, and slightly dangerous.

You can:

• Build **solar systems** and unstable cosmic setups  
• Add **planets, moons, stars, gas giants, black holes, and white holes**  
• Watch objects **orbit, drift, collide, transform, or collapse**  
• Collect and upgrade **Planet Cards**  
• Unlock **rare achievements**  
• Use **Apollo** for commands, ideas, and generated challenges  
• Create absolute galaxy-level nonsense, on purpose  

---

$\LARGE \color{#FFD166}{\textsf{DOCUMENTATION}}$

The full project documentation is available here:

[Open Unilearn Documentation](docs/UNILEARN_DOC_V2.pdf)

It covers the **concept**, **game systems**, **visual direction**, **technical structure**, and **implementation details** behind the project.

---

$\LARGE \color{#FFD166}{\textsf{TECH\ STACK}}$

• **Godot 4.6** for the Android game and UI  
• **GDScript** for gameplay systems, simulation logic, cards, achievements, and progression  
• **GDShader** for animated space, planets, and cosmic effects  
• **Java + Kotlin** for Android-specific plugin support  
• **ApolloSpeechPlugin** for native Android speech features  
• **Firebase Authentication** for player accounts  
• **Firestore** for saved cards, achievements, galaxies, and player progress  
• **Node.js + Express** for AI generation, Apollo requests, quizzes, and player initialization  
• **OpenAI-powered backend systems** for generated game content, commands, and card data  

---

$\LARGE \color{#FFD166}{\textsf{PROJECT\ STRUCTURE}}$

```txt
unilearn-extended/
├── ApolloSpeechPlugin/      # Native Android speech plugin source
├── docs/                    # Project documentation
├── godot/                   # Main Godot 4.6 project
│   ├── addons/              # Godot plugins and custom libraries
│   ├── android/             # Android export/build integration
│   ├── android_plugin/      # Android plugin bridge
│   ├── app/                 # Game screens, simulator, AI, cards, achievements
│   ├── assets/              # Fonts, audio, sprites, visual resources
│   ├── services/            # Firebase, backend, cache, auth, and data services
│   ├── shaders/             # Space and planet visual shaders
│   └── project.godot        # Godot project configuration
├── tools/audio_generator/   # Audio helper tooling
├── LICENCE
└── README.md
```

---

$\LARGE \color{#FFD166}{\textsf{GAME\ SYSTEMS}}$

$\large \color{#8FD8FF}{\textsf{Apollo\ AI}}$

**Apollo** is Unilearn's in-game AI companion.  
It handles **commands**, **generated cards**, **quizzes**, guided actions, and cosmic ideas.

$\large \color{#8FD8FF}{\textsf{Planet\ Cards}}$

**Planet Cards** work like collectible cosmic profiles.  
They include stats, levels, generated profiles, visual identity, progression, and challenge-ready data.

$\large \color{#8FD8FF}{\textsf{Galaxy\ Simulator}}$

The **Galaxy Simulator** is the main playground.  
Players create systems, throw objects into orbit, trigger collisions, form binaries, evolve bodies, and watch the universe react.

$\large \color{#8FD8FF}{\textsf{Achievements}}$

**Achievements** reward rare events, strange experiments, and perfectly unnecessary cosmic chaos.

$\large \color{#8FD8FF}{\textsf{Quizzes}}$

**Quizzes** act like fast challenge moments inside the game loop, keeping the pace active without interrupting the sandbox flow.

---

$\LARGE \color{#FFD166}{\textsf{PLATFORM\ SUPPORT}}$

**Unilearn is designed as an Android-only mobile game.**

• **Android:** main target platform  
• **Desktop:** development and editor testing  
• **iOS:** not currently supported  
• **Web:** not currently supported  

---

$\LARGE \color{#FFD166}{\textsf{RUNNING\ THE\ PROJECT}}$

1. Install **Godot 4.6** or a compatible Godot 4.x build.
2. Clone the repository:

```bash
git clone https://github.com/adisimaimulte1/unilearn-extended.git
```

3. Open the `godot/` folder in Godot.
4. Let Godot import the project assets.
5. Run the main scene:

```txt
res://app/splash/SplashScreen.tscn
```

6. For Android builds, configure the Android export templates and export from Godot.

Online features require the correct **Firebase credentials** and **backend environment variables**.

---

$\LARGE \color{#FFD166}{\textsf{BACKEND\ AND\ DATA}}$

Unilearn uses a backend-supported architecture for **AI**, **progression**, and **cloud sync**.

The backend handles:

• Firebase ID token verification  
• Player initialization  
• Planet-card seeding and generation  
• Apollo chat and in-game commands  
• AI challenge generation  
• Progress and achievement sync  

Typical player data is organized around:

```txt
players/{uid}
├── planetCards/
├── achievements/
└── galaxies/
```

---

$\LARGE \color{#FFD166}{\textsf{DESIGN\ DIRECTION}}$

Unilearn uses a **cosmic**, **playful**, high-contrast game style built around:

• Animated space backgrounds  
• Pixel planet visuals  
• Collectible card UI  
• Smooth popups and bouncy interactions  
• White, blue, and gold highlights  
• Sound effects and music-driven feedback  
• A futuristic interface that feels alive  

---

$\LARGE \color{#FFD166}{\textsf{ROADMAP}}$

• Expand **Apollo's in-game control**  
• Add more generated cosmic object types  
• Improve simulator stability and orbital behavior  
• Polish Planet Card animations  
• Expand achievements, rare events, and progression loops  
• Improve quizzes and challenge feedback  
• Add more sound, music, and visual polish  
• Prepare public Android release builds  

---

$\LARGE \color{#FFD166}{\textsf{LICENSE}}$

This project is released under the **MIT License**.

See the `LICENCE` file for full terms.

---

$\LARGE \color{#FFD166}{\textsf{MAINTAINER}}$

Created and maintained with **LOVE** by [Contraș Adrian](https://github.com/adisimaimulte1).

For feedback, ideas, or collaboration, use the GitHub repository or future in-game contact options.
