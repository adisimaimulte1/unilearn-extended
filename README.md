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

Create unstable systems, throw planets into orbit, collect **Planet Cards**, trigger black hole disasters, unlock achievements, and experiment with a galaxy that actually reacts.

This is not a static space app.  
It is a **playable universe**.

---

$\LARGE \color{#FFD166}{\textsf{FEATURES}}$

• **Universe sandbox** with planets, moons, stars, black holes, white holes, and custom systems  
• **Galaxy Simulator** with stable orbits, collisions, trails, gravity behavior, and object evolution  
• **Planet Cards** with stats, levels, generated profiles, progression, and collectible-style presentation  
• **Achievements** for rare events, strange systems, transformations, and cosmic chaos  
• **Apollo AI** for in-game commands, generated cards, quizzes, and guided actions  
• **Firebase sync** for accounts, saved progress, achievements, galaxies, and player data  
• **Android speech plugin**, pixel-style planets, shaders, sound effects, and a high-contrast space UI  

---

$\LARGE \color{#FFD166}{\textsf{GAMEPLAY}}$

Unilearn is built around **experimentation**.

Build systems, add celestial bodies, watch them **orbit, drift, collide, transform, collapse**, or spiral into complete disaster. Every action is direct, reactive, and slightly dangerous.

You can create **solar systems**, collect **Planet Cards**, unlock **rare achievements**, use **Apollo**, and cause galaxy-level nonsense on purpose.

---

$\LARGE \color{#FFD166}{\textsf{DOCUMENTATION}}$

The full project documentation is available here:

[Open Unilearn Documentation](docs/UNILEARN_DOC_V2.pdf)

It covers the **concept**, **game systems**, **visual direction**, **technical structure**, and **implementation details** behind the project.

---

$\LARGE \color{#FFD166}{\textsf{TECH\ STACK}}$

• **Godot 4.6** + **GDScript** for the Android game, UI, simulation, cards, achievements, and progression  
• **GDShader** for animated space, planets, and cosmic effects  
• **Java + Kotlin** with **ApolloSpeechPlugin** for native Android speech features  
• **Firebase Authentication** + **Firestore** for accounts, saved cards, achievements, galaxies, and progress  
• **Node.js + Express** backend for AI generation, Apollo requests, quizzes, and player initialization  
• **OpenAI-powered systems** for generated game content, commands, and card data  

---

$\LARGE \color{#FFD166}{\textsf{PROJECT\ STRUCTURE}}$

```txt
unilearn-extended/
├── ApolloSpeechPlugin/      # Native Android speech plugin
├── docs/                    # Project documentation
├── godot/                   # Main Godot 4.6 project
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

**Apollo** is Unilearn's in-game AI companion for **commands**, **generated cards**, quizzes, guided actions, and cosmic ideas.

$\large \color{#8FD8FF}{\textsf{Planet\ Cards}}$

**Planet Cards** are collectible cosmic profiles with stats, levels, generated profiles, visual identity, progression, and challenge-ready data.

$\large \color{#8FD8FF}{\textsf{Galaxy\ Simulator}}$

The **Galaxy Simulator** is the main playground: create systems, throw objects into orbit, trigger collisions, form binaries, evolve bodies, and watch the universe react.

---

$\LARGE \color{#FFD166}{\textsf{RUNNING\ THE\ PROJECT}}$

$\large \color{#8FD8FF}{\textsf{Download\ the\ Android\ build}}$

The easiest way to try Unilearn is to download the latest Android build from the **Releases** section of this GitHub repository.

$\large \color{#8FD8FF}{\textsf{Run\ from\ source}}$

1. Install **Godot 4.6** or a compatible Godot 4.x build.
2. Clone the repository:

```bash
git clone https://github.com/adisimaimulte1/unilearn-extended.git
```

3. Open the `godot/` folder in Godot.
4. Run the main scene:

```txt
res://app/splash/SplashScreen.tscn
```

5. For Android builds, configure the Android export templates and export from Godot.

Online features require the correct **Firebase credentials** and **backend environment variables**.

---

$\LARGE \color{#FFD166}{\textsf{BACKEND\ AND\ DATA}}$

Unilearn uses a backend-supported architecture for **AI**, **progression**, and **cloud sync**.

```txt
players/{uid}
├── planetCards/
└── achievements/
```

The backend handles **player initialization**, **planet-card generation**, **Apollo commands**, **AI challenges**, and **progress sync**.

---

$\LARGE \color{#FFD166}{\textsf{PLATFORM}}$

**Unilearn is designed as an Android-only mobile game.**

• **Android:** main target platform  
• **Desktop:** development and editor testing  
• **iOS/Web:** not currently supported  

---

$\LARGE \color{#FFD166}{\textsf{ROADMAP}}$

• Expand **Apollo's in-game control**  
• Add more generated cosmic object types  
• Improve simulator stability and orbital behavior  
• Polish **Planet Card** animations  
• Expand achievements, rare events, and progression loops  
• Add more sound, music, and visual polish  

---

$\LARGE \color{#FFD166}{\textsf{LICENSE}}$

This project is released under the **MIT License**.  
See the `LICENCE` file for full terms.

---

$\LARGE \color{#FFD166}{\textsf{MAINTAINER}}$

Created and maintained with **LOVE** by [Contraș Adrian](https://github.com/adisimaimulte1).

For feedback, ideas, or collaboration, use the GitHub repository or future in-game contact options.
