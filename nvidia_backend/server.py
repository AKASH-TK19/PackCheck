import os
import base64
import tempfile
import requests

from fastapi import FastAPI, UploadFile, File, HTTPException
from dotenv import load_dotenv

# RapidOCR is a free, offline OCR engine (ONNXRuntime). No API key required.
# It is imported lazily so the server still runs if the package is missing.
try:
    from rapidocr_onnxruntime import RapidOCR
    _RAPID_OCR_AVAILABLE = True
except Exception:  # pragma: no cover - optional dependency
    RapidOCR = None
    _RAPID_OCR_AVAILABLE = False

load_dotenv()

app = FastAPI()

NVIDIA_API_KEY = os.getenv("NVIDIA_API_KEY")
NVIDIA_URL = "https://integrate.api.nvidia.com/v1/chat/completions"
MODEL = "nvidia/nemotron-3-nano-omni-30b-a3b-reasoning"

# Lazy singleton so the model only loads when a request actually needs it.
_ocr_engine = None


def get_ocr_engine():
    global _ocr_engine
    if _ocr_engine is None and _RAPID_OCR_AVAILABLE:
        _ocr_engine = RapidOCR()
    return _ocr_engine


def ocr_one(data: bytes, filename: str):
    """Run RapidOCR on a single image and return (text, boxes).

    Returns ("", []) on any failure or when the engine is unavailable so the
    caller can degrade gracefully to the manual-entry path. `boxes` is a list
    of dicts (text/x/y/width/height) used by the font-size/readability checks.
    """
    if not _RAPID_OCR_AVAILABLE:
        return "", []

    engine = get_ocr_engine()
    if engine is None:
        return "", []

    tmp_path = None
    try:
        suffix = os.path.splitext(filename or "image.jpg")[1]
        if not suffix:
            suffix = ".jpg"

        fd, tmp_path = tempfile.mkstemp(suffix=suffix)
        with os.fdopen(fd, "wb") as f:
            f.write(data)

        result, _ = engine(tmp_path)

        text_lines = []
        boxes = []
        for item in (result or []):
            # RapidOCR returns [box(4 points), text, score]
            if not isinstance(item, (list, tuple)) or len(item) < 2:
                continue
            text = str(item[1]).strip()
            if not text:
                continue

            text_lines.append(text)

            points = item[0]
            xs = [p[0] for p in points]
            ys = [p[1] for p in points]

            boxes.append({
                "text": text,
                "x": float(min(xs)),
                "y": float(min(ys)),
                "width": float(max(xs) - min(xs)),
                "height": float(max(ys) - min(ys)),
            })

        return "\n".join(text_lines), boxes
    except Exception:
        return "", []
    finally:
        if tmp_path and os.path.exists(tmp_path):
            os.unlink(tmp_path)


def ocr_boxes(data: bytes, filename: str):
    """Run RapidOCR on a single image and return per-word bounding boxes.

    A thin wrapper over ocr_one() so the existing caller keeps working.
    """
    _, boxes = ocr_one(data, filename)
    return boxes


def image_to_data_url(data: bytes, filename: str) -> str:
    name = filename.lower()

    if name.endswith(".png"):
        mime = "image/png"
    elif name.endswith(".webp"):
        mime = "image/webp"
    else:
        mime = "image/jpeg"

    encoded = base64.b64encode(data).decode("utf-8")
    return f"data:{mime};base64,{encoded}"


@app.get("/")
def health():
    return {"status": "PackCheck NVIDIA OCR backend running"}


@app.post("/analyze")
async def analyze(images: list[UploadFile] = File(...)):

    # Read every upload once. Keep the bytes so we can run the free offline
    # OCR fallback even when the NVIDIA API is unreachable or rate-limited.
    image_blobs = []
    for image in images:
        data = await image.read()
        image_blobs.append((data, image.filename or "image.jpg"))

    if not image_blobs:
        raise HTTPException(status_code=400, detail="No images uploaded")

    # Free, offline OCR text + per-word geometry (runs regardless of NVIDIA).
    fallback_text = ""
    fallback_boxes = []
    for data, name in image_blobs:
        text, boxes = ocr_one(data, name)
        if text:
            fallback_text = fallback_text + "\n" + text if fallback_text else text
        fallback_boxes.extend(boxes)

    if not NVIDIA_API_KEY:
        # No key, no point calling NVIDIA: serve the offline OCR result.
        if not fallback_text:
            raise HTTPException(
                status_code=503,
                detail="NVIDIA_API_KEY is missing and no OCR text could be extracted.",
            )
        return {
            "result": fallback_text,
            "boxes": fallback_boxes,
            "source": "rapidocr",
            "notice": "NVIDIA_API_KEY is missing; served free offline OCR text.",
        }

    content = [
        {
            "type": "text",
            "text": """
You are the vision extraction engine for PackCheck.

Analyze ALL supplied photographs as different views of the SAME
packaged commodity.

Extract ONLY information that is visibly supported by the photographs.

DO NOT GUESS.

Return ONLY valid JSON in this exact structure:

{
  "productName": "",
  "mrp": "",
  "unitSalePrice": "",
  "netQuantity": "",
  "manufacturer": "",
  "countryOfOrigin": "",
  "manufactureDate": "",
  "expiryDate": "",
  "consumerCare": "",
  "rawRelevantText": ""
}

Rules:

1. MRP must be the actual Maximum Retail Price printed on the package.
2. Do NOT confuse MRP with unit sale price.
3. Unit sale price must be reported separately.
4. Manufacture/packing date must be taken ONLY from a date explicitly
   associated with labels such as PKD, P.K.D., PACKED, PACKING DATE,
   MFD, MFG, MANUFACTURED, MANUFACTURING DATE, or DATE OF PACKING.
5. Expiry date must be taken ONLY from a date explicitly associated
   with labels such as EXP, EXP., EXPIRY, EXPIRY DATE, USE BY,
   USE-BY, or BEST BEFORE when a specific expiry date is printed.
6. BEST BEFORE may be expressed as a duration such as "12 months",
   "18 months", or "24 months". Preserve that duration exactly if
   no specific expiry date is printed.
7. NEVER assign a date to manufactureDate or expiryDate merely because
   the date is physically aligned with another printed label.
   The nearby label or text must identify what the date means.
8. PKD means PACKING DATE unless the package explicitly defines it
   differently. Do not interpret PKD as expiry.
9. EXP means EXPIRY. Do not interpret EXP as manufacture/packing date.
10. If both PKD/MFD and EXP dates are visible, independently identify
    each label and assign each date to the correct field.
11. If a date is difficult to read, return an empty string rather than
    guessing or converting it into another date.
12. Manufacturer/packer/importer must be copied from the actual
    manufacturer/packer/importer section, not from consumer-care text.
13. Consumer care must come ONLY from text explicitly related to
    consumer/customer care or customer service. Look carefully for
    "Consumer Care", "Customer Care", "Customer Service", "Care",
    "Contact", telephone numbers, email addresses, websites, or
    customer-support addresses.
14. Do NOT use the manufacturer's address or unrelated phone number
    as Consumer Care unless the package clearly associates it with
    consumer/customer support.
15. Product name should be the actual product name, not ingredients,
    nutrition information, or a random line of text.
16. Use information from ALL supplied photographs. They are different
    views of the SAME package.
17. Extract ONLY information visibly supported by the photographs.
18. DO NOT GUESS.
19. Preserve dates, numbers, units, punctuation, phone numbers, email
    addresses, and visible wording as closely as possible.
"""
        }
    ]

    for data, name in image_blobs:
        content.append({
            "type": "image_url",
            "image_url": {
                "url": image_to_data_url(data, name)
            }
        })

    payload = {
        "model": MODEL,
        "messages": [
            {
                "role": "user",
                "content": content
            }
        ],
        "max_tokens": 4096,
        "stream": False,
        "chat_template_kwargs": {
            "enable_thinking": False
        }
    }

    try:
        response = requests.post(
            NVIDIA_URL,
            headers={
                "Authorization": f"Bearer {NVIDIA_API_KEY}",
                "Content-Type": "application/json",
                "Accept": "application/json",
            },
            json=payload,
            timeout=120,
        )
    except Exception as exc:  # network / timeout -> offline fallback
        if not fallback_text:
            raise HTTPException(
                status_code=503,
                detail=f"OCR backend unreachable: {exc}",
            )
        return {
            "result": fallback_text,
            "boxes": fallback_boxes,
            "source": "rapidocr",
            "notice": f"NVIDIA unreachable; served free offline OCR text. ({exc})",
        }

    if response.status_code != 200:
        # Rate limit, quota exhausted (503), auth error, etc. Instead of
        # failing the whole request, serve the free offline OCR result so the
        # inspection flow still produces text and readable/placement checks.
        if not fallback_text:
            raise HTTPException(
                status_code=response.status_code,
                detail=response.text,
            )
        return {
            "result": fallback_text,
            "boxes": fallback_boxes,
            "source": "rapidocr",
            "notice": (
                "NVIDIA returned HTTP "
                f"{response.status_code}; served free offline OCR text. "
                f"{response.text[:200]}"
            ),
        }

    result = response.json()

    text = (
        result["choices"][0]["message"]["content"]
        .strip()
    )

    return {
        "result": text,
        "boxes": fallback_boxes,
        "source": "nvidia",
    }