import os
import json
from pathlib import Path

from dotenv import load_dotenv
from openai import OpenAI


# Folder where this script lives:
# Unilearn/tools/audio_generator/generate_ai_audio.py
SCRIPT_DIR = Path(__file__).resolve().parent

# Load .env from this same folder
load_dotenv(SCRIPT_DIR / ".env")

client = OpenAI(api_key=os.environ["OPENAI_API_KEY"])

# Your repo structure:
# Unilearn/
#   godot/
#     assets/audio/ai/
GODOT_PROJECT_DIR = SCRIPT_DIR.parent.parent / "godot"
AUDIO_ROOT = GODOT_PROJECT_DIR / "assets" / "audio" / "ai"

RESPONSES_FILE = SCRIPT_DIR / "prompts.json"

MODEL = "tts-1"
VOICE = "echo"
SPEED = 1.0

RESPONSES_PER_FOLDER = 20


def load_responses() -> dict:
    if not RESPONSES_FILE.exists():
        raise FileNotFoundError(f"Missing responses file: {RESPONSES_FILE}")

    with open(RESPONSES_FILE, "r", encoding="utf-8") as f:
        return json.load(f)


def generate_tts(text: str, out_path: Path) -> None:
    out_path.parent.mkdir(parents=True, exist_ok=True)

    print(f"Generating: {out_path}")

    response = client.audio.speech.create(
        model=MODEL,
        voice=VOICE,
        input=text,
        speed=SPEED,
    )

    out_path.write_bytes(response.content)
    print(f"Saved: {out_path}")


def generate_folder(folder_path: str, prompts: list[str]) -> None:
    if len(prompts) != RESPONSES_PER_FOLDER:
        raise ValueError(
            f"'{folder_path}' needs exactly {RESPONSES_PER_FOLDER} responses, "
            f"but has {len(prompts)}."
        )

    target_folder = AUDIO_ROOT / Path(folder_path)

    for index, prompt in enumerate(prompts, start=1):
        out_file = target_folder / f"{index}.mp3"
        generate_tts(prompt, out_file)


def main() -> None:
    responses = load_responses()

    for folder_path, prompts in responses.items():
        generate_folder(folder_path, prompts)

    print("Done. All Apollo voice lines generated.")


if __name__ == "__main__":
    main()