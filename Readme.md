# PointCloud Video Reconstruction Pipeline

A local pipeline for generating 3D point clouds from video input using **COLMAP / GLOMAP**.  
Designed to be extended into a **web-based system** (API + worker architecture).

---

## Overview

This project converts a video into a reconstructed 3D scene using the following stages:




The output can later be visualized on the web using Three.js, Potree, or Gaussian Splat viewers.

---

## Folder Structure



PointCloudV1/
├── 01_GLOMAP/ # GLOMAP / COLMAP binaries & configs
├── 02_VIDEOS/ # Input videos
├── 03_FFMPEG/ # Frame extraction utilities
├── 04_SCENES/ # Reconstruction outputs (point clouds, sparse/dense models)
├── 05_SCRIPT/ # Python automation scripts
└── README.md



---

If you want, next I can:
- Tighten this for **open-source**
- Rewrite it for a **SaaS / product repo**
- Add **Docker + API README sections**
- Or align it with **investor / technical due diligence**

Just tell me which direction you want.
