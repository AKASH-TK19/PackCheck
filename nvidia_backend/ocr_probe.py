import sys
from rapidocr_onnxruntime import RapidOCR

print('IMPORT_OK', RapidOCR)
sys.stdout.flush()

engine = RapidOCR()
print('ENGINE_OK')
sys.stdout.flush()

import numpy as np
import cv2

img = np.full((120, 600, 3), 255, dtype=np.uint8)
cv2.putText(img, 'MRP Rs. 100 NET WT 500g', (10, 70), cv2.FONT_HERSHEY_SIMPLEX, 1.0, (0, 0, 0), 2)
cv2.imwrite('ocr_probe.png', img)

result, elapse = engine('ocr_probe.png')
print('CALL_OK type=', type(result).__name__)
sys.stdout.flush()

files = result if result else []
print('NUM_BOXES', len(files))
for item in files[:5]:
    xs = [p[0] for p in item[0]]
    ys = [p[1] for p in item[0]]
    print('BOX', item[1], float(min(xs)), float(min(ys)),
          float(max(xs) - min(xs)), float(max(ys) - min(ys)))
sys.stdout.flush()
