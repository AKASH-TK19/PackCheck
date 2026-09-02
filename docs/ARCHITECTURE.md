# LM Inspect — Technical Architecture & Deployment Framework

This document describes the software architecture, data model, major components
and the deployment framework for **LM Inspect**, a Legal Metrology (Packaged
Commodities) Rules, 2011 compliance-screening application.

---

## 1. System overview

LM Inspect is a two-part system:

1. **Flutter client** (`lib/`) — mobile-first UI that captures package evidence,
   runs local rule-based validation, stores inspections locally and produces
   reports.
2. **NVIDIA OCR/vision backend** (`nvidia_backend/`) — an HTTP service that
   receives evidence photographs, sends them to the NVIDIA vision model, and
   returns structured declaration fields as JSON.

The two communicate over HTTP using a single endpoint, `/analyze`. The app is
designed so that if the backend is unavailable, an officer can continue by
entering label text manually — the rest of the pipeline (validation, reports,
repository) runs entirely on-device.

```
┌────────────────────────────────────────────────────────────────┐
│                     Flutter client (mobile)                    │
│                                                                │
│  NewInspection ──▶ OcrService ──┐                               │
│        │                        │  HTTP /analyze               │
│        ▼                        ▼                              │
│  BarcodeService          ┌──────────────────┐                  │
│  (on-device, NVIDIA-     │ NVIDIA FastAPI   │                  │
│   independent)           │ backend          │                  │
│  ComplianceEngine        └───────┬──────────┘                  │
│  ReadabilityService              │ HTTPS                        │
│  UnitSalePriceService            ▼                              │
│  MultipackService           NVIDIA vision API                   │
│  MpeService                                                      │
│  ReportService (PDF/CSV)                                         │
│  DatabaseService (SQLite)                                        │
└────────────────────────────────────────────────────────────────┘
```

---

## 2. Component responsibilities

### Client (Flutter)

| Component | Responsibility |
| --- | --- |
| `main.dart` | App shell, navigation, screens (login, dashboard, new inspection, result, officer verification, history, repository, violation summary, coverage). |
| `BarcodeService` | On-device QR / 1-D barcode decoding of the captured package photo via `mobile_scanner` (`analyzeImage`). Fully independent of the NVIDIA/OCR backend; tolerates angled / off-centre codes; returns all unique decoded values so the officer can select the relevant one (or "No barcode/QR detected"). |
| `OcrService` | Sends evidence images to the backend; converts the model response into the PackCheck labelled text; parses optional per-line geometry (`boxes`); raises `OcrServiceException` on failure so the UI can offer manual entry. |
| `ComplianceEngine` | Pure rule engine. Validates the extracted text against configured `ComplianceRule`s and returns `ExtractedProductData` + `List<ComplianceResult>`. |
| `UnitSalePriceService` | Computes unit sale price per Rule 6(11) (percent-based and per-unit methods). |
| `MultipackService` | Expands multi-pack declarations (e.g. `5 x 100 g`) and validates net-quantity math. |
| `MpeService` | Provides preliminary maximum permissible-error tolerance screening. |
| `ReadabilityService` | Heuristic placement / readability / font-size assessment of the captured evidence. |
| `ReportService` | Generates the signed PDF report and the editable CSV export. |
| `DatabaseService` | SQLite repository for inspections; compute evidence SHA-256 for duplicate detection. |

### Backend (Python / FastAPI)

| Component | Responsibility |
| --- | --- |
| `server.py` | FastAPI app exposing `GET /` (health) and `POST /analyze`. Receives multipart images, builds the vision prompt, calls the NVIDIA API and returns `{"result": "<json text>"}`. |
| `.env` | Holds `NVIDIA_API_KEY` (loaded via `python-dotenv`). |

---

## 3. Data model

### SQLite (`lm_inspect.db`)

The `inspections` table stores one row per verified inspection:

| Column | Type | Meaning |
| --- | --- | --- |
| `id` | INTEGER PK | Auto-increment |
| `productName` | TEXT | Product name (officer-verified) |
| `inspectionDate` | TEXT | ISO-8601 timestamp |
| `extractedText` | TEXT | OCR text + audit metadata |
| `score` | INTEGER | Compliance score (0–100) |
| `violationCount` | INTEGER | Number of potential violations |
| `imagePath` | TEXT | Path to the primary evidence photograph |
| `evidenceKey` | TEXT | SHA-256 fingerprint for duplicate detection |
| `officerId` | TEXT | Verifying officer ID |
| `location` | TEXT | Inspection location |
| `officerRemarks` | TEXT | Verification remarks |
| `verified` | INTEGER | 1 when officer-verified |
| `productCategory` | TEXT | Selected product category label |

### Declarations (configured rules)

Rules live in `lib/data/compliance_rules.dart`. Each `ComplianceRule` defines a
label, expected pattern, whether it is conditional, and a violation description.
The engine evaluates every configured rule against the extracted text and
produces a `ComplianceResult` (`detected` / `conditional` / not-detected).

### Product categories

Before any image capture/upload the officer must select a product category on a
mandatory `ProductCategoryScreen`. The chosen category is carried through the
whole pipeline and stored in the `productCategory` DB column.

Categories are classified by two flags on `ProductCategoryInfo`:

- `isFood` — food/beverage categories run the food-specific Legal Metrology
  checks (best-before, unit sale price).
- `hasCategorySpecificRules` — whether category-specific mandatory declarations
  are implemented (garments, electronics, electrical, cosmetics, household).

Categories with neither flag (e.g. `Other Packaged Consumer Commodities`) are
shown as **advisory only** and are never labelled food-compliant. Food-specific
rules are never applied to non-food categories.

---

## 4. Compliance flow

0. **Category** — officer selects the product category on the mandatory
   `ProductCategoryScreen`; the inspection cannot begin without a selection.
1. **Capture** — officer photographs package sides (2 / 4 / 6 / custom).
2. **Barcode / QR (on-device)** — `BarcodeService` automatically decodes any QR
   or common 1-D product barcode from the captured photo via `mobile_scanner`.
   This is independent of the NVIDIA OCR backend. If several codes are found the
   officer selects the relevant one; if none are found the assessment continues
   without failing.
3. **OCR** — evidence images POSTed to the backend; structured fields returned.
4. **Extract** — `ComplianceEngine` produces product fields and per-rule results.
5. **Validate** — rule engine flags missing / invalid declarations.
6. **Screen** — `ReadabilityService` assesses placement / readability / font-size;
   `MpeService` / `UnitSalePriceService` add pricing quantity checks.
7. **Verify** — officer reviews and corrects fields, records ID + location.
8. **Record** — saved to SQLite with SHA-256 evidence fingerprint (duplicate
   guard).
9. **Report** — PDF + editable CSV generated and shared.
10. **Review** — dashboards, history & repository give enforcement visibility.

---

## 5. Security considerations

- **Credentials are prototype-only.** `LM001` / `ADM001` with the same password
  are hard-coded for the hackathon build. Production must use departmental
  authentication / SSO, salted hashed passwords, and server-side sessions.
- **`NVIDIA_API_KEY` must not be committed.** The `.env` file is loaded by
  `python-dotenv`; ensure it is in `.gitignore` and never committed. If it has
  been committed, rotate the key immediately.
- **Transport.** The Long-ish plain-HTTP `http://<ip>:8000` call to the backend
  is acceptable on a lab network. In production, terminate TLS and use HTTPS.
- **Least privilege.** Officers may capture and verify; repository deletion is
  admin-only. DB access should be scoped to the app sandbox.

---

## 6. Deployment framework

### Local / lab (current)

- Run the FastAPI backend on a machine reachable on the LAN:
  `uvicorn server:app --host 0.0.0.0 --port 8000`.
- Run the app with the backend URL injected:
  `flutter run --dart-define=PACKCHECK_OCR_URL=http://<host>:8000/analyze`.

### Production (recommended)

- **Client**: build signed APK / App Bundle (`flutter build apk --release`),
  distribute via MDM or an internal app store.
- **Backend**: containerise `server.py` (Docker), deploy behind a reverse proxy
  with TLS. Store `NVIDIA_API_KEY` in a secret manager, not in the image.
- **Database**: migrate to a managed / shared relational store (PostgreSQL) to
  enable multi-officer collaboration and central dashboards.
- **AuthN/AuthZ**: integrate departmental SSO; add per-officer audit trails and
  role-based authorization at the API layer.

---

## 7. Extending the rule engine

The engine is a **multi-category packaged-product compliance scanner**. Rules are
grouped into three tiers inside `lib/data/compliance_rules.dart`:

- `universalRules` — always applied to every category (manufacturer, net
  quantity, MRP, consumer care, country of origin, common name, date).
- `foodRules` — added for food / beverage categories (best-before, unit sale
  price).
- category rule lists (`garmentRules`, `electronicsRules`, `electricalRules`,
  `cosmeticsRules`, `householdRules`) — added per category key.

`ComplianceRules.rulesForCategory(category)` returns the ordered applicable set.

To add a new category or rule:

1. `lib/models/product_category.dart` — add a `ProductCategoryInfo` entry (with a
   stable `key`, `isFood`, `hasCategorySpecificRules`).
2. `lib/data/compliance_rules.dart` — add the rule(s) and add them to
   `rulesForCategory`.
3. `lib/services/compliance_engine.dart` — add the corresponding evaluation case
   in `_validate` (keyed by rule `id`).

The `Requirement Coverage` screen in the app tracks each problem-statement
requirement and its implementation status, so the system can be audited against
the brief directly.

The `Requirement Coverage` screen in the app tracks each problem-statement
requirement and its implementation status, so the system can be audited against
the brief directly.

---

## 8. Disclaimer

LM Inspect provides advisory, preliminary screening. Every inspection requires
an authorised officer verification before it is recorded. The application does
not render legal determinations under the Legal Metrology Act, 2009 or the Legal
Metrology (Packaged Commodities) Rules, 2011; final decisions rest with the
competent enforcement authority.
