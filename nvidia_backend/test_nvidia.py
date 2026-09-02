import os
import requests
from dotenv import load_dotenv

load_dotenv()

key = os.getenv("NVIDIA_API_KEY")

print("KEY LOADED:", bool(key))

response = requests.post(
    "https://integrate.api.nvidia.com/v1/chat/completions",
    headers={
        "Authorization": f"Bearer {key}",
        "Content-Type": "application/json",
    },
    json={
        "model": "nvidia/nemotron-3-nano-omni-30b-a3b-reasoning",
        "messages": [
            {
                "role": "user",
                "content": "Reply with the word TEST only."
            }
        ],
        "max_tokens": 10,
        "stream": False,
    },
    timeout=60,
)

print("STATUS:", response.status_code)
print("RESPONSE:", response.text)