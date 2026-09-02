# LM Inspect — Packaged Commodity Compliance Checker

**LM Inspect** (workspace name: *packcheck*) is a Flutter mobile application that
scans packaged-commodity labels and product images to automatically screen
compliance with the **Legal Metrology (Packaged Commodities) Rules, 2011**.

It captures package evidence (photos + barcode/QR), extracts the mandatory
declarations required under the Rules, validates them against a configurable
rule engine, checks the placement / readability / prominence of declarations,
and produces PDF and editable (CSV) compliance reports for enforcement
officials. Everything is designed around a **preliminary automated screen +
authorised officer verification** workflow.

> This project was developed as a response to a Smart India Hackathon (SIH)
> problem statement issued by the **Ministry of Consumer Affairs, Food &
> Public Distribution**.

---

## Problem statement

Packaged commodities sold across India must carry mandatory declarations —
name & address of manufacturer/packer/importer, net quantity, MRP, month & year
of manufacture/packing, consumer-care details and more — in a prescribed format.
Manual inspection by enforcement agencies is time-consuming and resource-heavy,
and non-compliance (missing declarations, wrong font sizes, improper MRP
declarations) is common.

An automated system is required that can scan labels, package images and product
listings, detect and validate mandatory declarations, and identify violations.

---

## Feature coverage

| Area | Implementation |
| --- | --- |
| Image upload & multi-side capture | Camera / gallery evidence, configurable package sides (2 / 4 / 6 / custom) |
| Barcode / QR scanning | Automatic on-device `mobile_scanner` decoding of the captured package photo (QR + EAN-13 / EAN-8 / UPC-A / Code 128 / Code 39 / ITF-14), independent of the NVIDIA OCR backend; angled/off-centre codes supported; multiple codes prompt the officer to select; "No barcode/QR detected" never fails the assessment |
| Declaration extraction | NVIDIA vision backend → structured product fields |
| Rule-based validation | `ComplianceRule` engine (LM-01 … LM-10) covering MRP, net qty, manufacturer, origin, dates, consumer care |
| Unit sale price (Rule 6(11)) | `UnitSalePriceService` (percent & per-unit logic) |
| Multi-pack handling | `MultipackService` |
| MPE / tolerance | `MpeService` (preliminary tolerance screening) |
| Placement / readability / font-size | `ReadabilityService` |
| Compliance / non-compliance report | `ReportService` → PDF |
| Editable export | `ReportService` → CSV (share sheet) |
| Evidence attachment | Evidence photograph embedded in PDF, SHA-256 fingerprint for duplicate detection |
| Repository & inspection history | SQLite (`DatabaseService`) |
| Search / retrieval | Product Repository + history screens |
| Enforcement dashboard | Stats, compliance ring, violation summary |
| Role-based access | Officer (`LM001`) and Admin (`ADM001`) accounts; deletion is admin-only |
| Automated coverage tracker | In-app `Requirement Coverage` screen |

---

## Architecture

See [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) for the full technical
architecture and deployment framework. In short:

```
Flutter app (mobile / tablet)
  ├── BarcodeService (on-device) → QR / 1-D barcode decode of the package photo (independent of NVIDIA)
  └── OcrService  ── HTTP ──>  NVIDIA vision backend (FastAPI, /analyze)
                                    └── NVIDIA Nemotron vision model
  ├── ComplianceEngine        → rule-based declaration validation
  ├── UnitSalePriceService    → Rule 6(11) unit sale price
  ├── MultipackService        → multi-pack expansion
  ├── MpeService              → maximum permissible error screening
  ├── ReadabilityService      → placement / readability / font-size
  ├── ReportService           → PDF + CSV export
  └── DatabaseService         → SQLite repository (local, on-device)
```

---

## Prerequisites

- Flutter SDK (Dart 3.x) — see `pubspec.yaml` (`sdk: ^3.11.5`)
- An Android device / emulator (camera + mobile scanner) or a Windows/Web target
- Python 3.10+ for the NVIDIA OCR backend
- An NVIDIA API key (stored in `nvidia_backend/.env`)

---

## Running the OCR backend

The Flutter app does not perform OCR itself; it calls a small FastAPI service
that forwards evidence images to the NVIDIA vision API and returns structured
declaration fields.

```bash
cd nvidia_backend
python -m venv .venv
.venv\Scripts\activate            # Windows
# source .venv/bin/activate       # Linux / macOS

pip install -r requirements.txt

# Put your key in nvidia_backend/.env :  NVIDIA_API_KEY=nvapi-...
uvicorn server:app --host 0.0.0.0 --port 8000
```

Verify: `curl http://localhost:8000/` → `{"status": "PackCheck NVIDIA OCR backend running"}`

---

## Running the Flutter app

The app resolves the OCR backend URL from a compile-time define, falling back to
a default. Point it at the machine running the backend:

```bash
flutter run \
  --dart-define=PACKCHECK_OCR_URL=http://<backend-host>:8000/analyze
```

If the backend is unreachable the app offers a **manual label-text entry**
fallback so the compliance engine still runs in offline/lab demonstrations.

The database is on-device SQLite. No separate API server or web host is needed.

---

## Demo credentials (hackathon prototype)

| Role | ID | Password |
| --- | --- | --- |
| Officer | `LM001` | `LM@1234` |
| Admin | `ADM001` | `LM@1234` |

> These are prototype credentials only. Production must use departmental
> authentication / SSO and never hard-code secrets (see
> [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) → Security).

---

## Testing & analysis

```bash
flutter pub get
flutter analyze
flutter test
```

---

## Disclaimer

LM Inspect provides a **preliminary, advisory** compliance screen. Every
inspection flows through an authorised officer verification step before an
inspection is recorded. Nothing in this application constitutes a legal
judgment; final determinations rest with the enforcement authority under the
Legal Metrology Act, 2009 and the Legal Metrology (Packaged Commodities) Rules,
2011.
