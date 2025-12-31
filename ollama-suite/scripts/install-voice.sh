#!/bin/bash

################################################################################
# Voice Integration Installation Module
# Installs: Whisper, Piper TTS, Voice Assistant
################################################################################

source "$(dirname "$0")/../install-ollama-suite.sh" 2>/dev/null || true

install_voice() {
    print_header "Installing Voice Integration"

    install_whisper
    install_piper_tts
    create_voice_assistant

    print_status "Voice integration installed!"
}

install_whisper() {
    print_status "Installing Whisper (Speech-to-Text)..."

    pip install openai-whisper --break-system-packages 2>/dev/null || \
    pip install openai-whisper

    # Install ffmpeg for audio processing
    sudo apt install -y ffmpeg

    # Create Whisper test script
    cat > "$PROJECTS_DIR/whisper_test.py" << 'EOF'
#!/usr/bin/env python3
"""
Whisper Speech-to-Text Example
"""

import whisper
import sys

def transcribe_audio(audio_file, model_size="base"):
    """Transcribe audio file to text"""

    print(f"Loading Whisper model: {model_size}...")
    model = whisper.load_model(model_size)

    print(f"Transcribing {audio_file}...")
    result = model.transcribe(audio_file)

    return result["text"]

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python whisper_test.py <audio_file.wav> [model_size]")
        print("Model sizes: tiny, base, small, medium, large")
        sys.exit(1)

    audio_file = sys.argv[1]
    model_size = sys.argv[2] if len(sys.argv) > 2 else "base"

    text = transcribe_audio(audio_file, model_size)
    print(f"\nTranscription:\n{text}")
EOF

    chmod +x "$PROJECTS_DIR/whisper_test.py"

    print_status "Whisper installed!"
    print_info "Test with: python whisper_test.py audio.wav"
}

install_piper_tts() {
    print_status "Installing Piper TTS (Text-to-Speech)..."

    cd "$PROJECTS_DIR"
    mkdir -p piper-tts
    cd piper-tts

    # Download Piper
    wget https://github.com/rhasspy/piper/releases/latest/download/piper_linux_x86_64.tar.gz
    tar -xzf piper_linux_x86_64.tar.gz
    rm piper_linux_x86_64.tar.gz

    # Download a voice model
    wget https://huggingface.co/rhasspy/piper-voices/resolve/main/en/en_US/lessac/medium/en_US-lessac-medium.onnx
    wget https://huggingface.co/rhasspy/piper-voices/resolve/main/en/en_US/lessac/medium/en_US-lessac-medium.onnx.json

    # Create TTS test script
    cat > tts_test.sh << 'EOF'
#!/bin/bash
# Piper TTS Test Script

TEXT="${1:-Hello, this is a test of the Piper text to speech system.}"
OUTPUT="${2:-output.wav}"

echo "$TEXT" | ./piper --model en_US-lessac-medium.onnx --output_file "$OUTPUT"

echo "Audio saved to: $OUTPUT"
echo "Playing..."
aplay "$OUTPUT" 2>/dev/null || echo "Install aplay to play audio: sudo apt install alsa-utils"
EOF

    chmod +x tts_test.sh

    print_status "Piper TTS installed!"
    print_info "Test with: cd $PROJECTS_DIR/piper-tts && ./tts_test.sh 'Hello world'"
}

create_voice_assistant() {
    print_status "Creating voice assistant..."

    cat > "$PROJECTS_DIR/voice_assistant.py" << 'EOF'
#!/usr/bin/env python3
"""
Voice Assistant with Ollama
Combines Whisper (STT) + Ollama (LLM) + Piper (TTS)
"""

import whisper
import ollama
import subprocess
import sys
import os
import tempfile

class VoiceAssistant:
    def __init__(self, model="deepseek-r1:7b", whisper_model="base"):
        """Initialize voice assistant"""

        print("Initializing Voice Assistant...")

        # Whisper for speech-to-text
        print(f"Loading Whisper model: {whisper_model}")
        self.whisper = whisper.load_model(whisper_model)

        # Ollama model
        self.model = model

        # Piper TTS path
        self.piper_dir = os.path.expanduser("~/ollama-suite/projects/piper-tts")
        self.piper_bin = f"{self.piper_dir}/piper"
        self.piper_model = f"{self.piper_dir}/en_US-lessac-medium.onnx"

        # Conversation history
        self.history = []

        print("Voice Assistant ready!")

    def transcribe(self, audio_file):
        """Convert speech to text"""
        print("Transcribing audio...")
        result = self.whisper.transcribe(audio_file)
        return result["text"]

    def chat(self, text):
        """Get response from Ollama"""
        print(f"You: {text}")

        # Add to history
        self.history.append({"role": "user", "content": text})

        # Query Ollama
        print("Thinking...")
        response = ollama.chat(
            model=self.model,
            messages=self.history
        )

        assistant_reply = response["message"]["content"]

        # Add to history
        self.history.append({"role": "assistant", "content": assistant_reply})

        print(f"Assistant: {assistant_reply}")
        return assistant_reply

    def speak(self, text):
        """Convert text to speech"""
        print("Speaking...")

        with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as f:
            output_file = f.name

        try:
            # Generate speech
            subprocess.run(
                [self.piper_bin, "--model", self.piper_model, "--output_file", output_file],
                input=text.encode(),
                check=True,
                capture_output=True
            )

            # Play audio
            subprocess.run(["aplay", output_file], check=True, capture_output=True)

        finally:
            # Cleanup
            if os.path.exists(output_file):
                os.unlink(output_file)

    def voice_conversation(self, audio_file):
        """Complete voice interaction"""

        # Speech to text
        text = self.transcribe(audio_file)

        # Get LLM response
        response = self.chat(text)

        # Text to speech
        self.speak(response)

        return response

    def interactive_mode(self):
        """Interactive text mode (no voice input)"""

        print("\n" + "="*60)
        print("Voice Assistant - Interactive Mode")
        print("="*60)
        print("Type 'quit' to exit, 'clear' to reset conversation")
        print("="*60 + "\n")

        while True:
            try:
                user_input = input("You: ").strip()

                if user_input.lower() in ['quit', 'exit', 'q']:
                    print("Goodbye!")
                    break

                if user_input.lower() == 'clear':
                    self.history = []
                    print("Conversation history cleared.")
                    continue

                if not user_input:
                    continue

                # Get response
                response = self.chat(user_input)

                # Optionally speak the response
                speak = input("Speak response? (y/N): ").strip().lower()
                if speak == 'y':
                    self.speak(response)

            except KeyboardInterrupt:
                print("\nGoodbye!")
                break

def main():
    """Main function"""

    if len(sys.argv) > 1:
        # Voice mode with audio file
        audio_file = sys.argv[1]
        model = sys.argv[2] if len(sys.argv) > 2 else "llama3.2:3b"

        assistant = VoiceAssistant(model=model)
        assistant.voice_conversation(audio_file)

    else:
        # Interactive text mode
        model = input("Enter model name (default: llama3.2:3b): ").strip() or "llama3.2:3b"
        assistant = VoiceAssistant(model=model)
        assistant.interactive_mode()

if __name__ == "__main__":
    main()
EOF

    chmod +x "$PROJECTS_DIR/voice_assistant.py"

    # Create recording script
    cat > "$PROJECTS_DIR/record_audio.sh" << 'EOF'
#!/bin/bash
# Simple audio recording script

OUTPUT="${1:-input.wav}"
DURATION="${2:-5}"

echo "Recording for ${DURATION} seconds..."
echo "Speak now!"

arecord -f cd -t wav -d "$DURATION" "$OUTPUT" 2>/dev/null

echo "Recording saved to: $OUTPUT"
EOF

    chmod +x "$PROJECTS_DIR/record_audio.sh"

    print_status "Voice assistant created!"
    print_info "Interactive mode: python $PROJECTS_DIR/voice_assistant.py"
    print_info "Voice mode: python $PROJECTS_DIR/voice_assistant.py audio.wav"
}

export -f install_voice
