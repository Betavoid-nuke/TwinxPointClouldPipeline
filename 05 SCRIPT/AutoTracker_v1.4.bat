:: ================================================================
::  BATCH SCRIPT FOR AUTOMATED PHOTOGRAMMETRY TRACKING WORKFLOW
::  By polyfjord - https://youtube.com/polyfjord
::  GLOMAP mapping (faster), COLMAP for features/matching + TXT export
:: ================================================================
@echo off
setlocal EnableExtensions EnableDelayedExpansion

:: ---------- Resolve top-level folder (one up from this .bat) -----
pushd "%~dp0\.." >nul
set "TOP=%cd%"

:: ---------- Key paths -------------------------------------------
set "SFM_DIR=%TOP%\01 GLOMAP"
set "VIDEOS_DIR=%TOP%\02 VIDEOS"
set "FFMPEG_DIR=%TOP%\03 FFMPEG"
set "SCENES_DIR=%TOP%\04 SCENES"

:: ---------- Locate ffmpeg.exe -----------------------------------
if exist "%FFMPEG_DIR%\ffmpeg.exe" (
    set "FFMPEG=%FFMPEG_DIR%\ffmpeg.exe"
) else if exist "%FFMPEG_DIR%\bin\ffmpeg.exe" (
    set "FFMPEG=%FFMPEG_DIR%\bin\ffmpeg.exe"
) else (
    echo [ERROR] ffmpeg.exe not found inside "%FFMPEG_DIR%".
    popd & pause & goto :eof
)

:: ---------- Locate glomap.exe -----------------------------------
if exist "%SFM_DIR%\glomap.exe" (
    set "GLOMAP=%SFM_DIR%\glomap.exe"
) else if exist "%SFM_DIR%\bin\glomap.exe" (
    set "GLOMAP=%SFM_DIR%\bin\glomap.exe"
) else (
    echo [ERROR] glomap.exe not found inside "%SFM_DIR%".
    popd & pause & goto :eof
)

:: ---------- Locate colmap.exe (DB + TXT export) ------------------
if exist "%SFM_DIR%\colmap.exe" (
    set "COLMAP=%SFM_DIR%\colmap.exe"
) else if exist "%SFM_DIR%\bin\colmap.exe" (
    set "COLMAP=%SFM_DIR%\bin\colmap.exe"
) else (
    echo [ERROR] colmap.exe not found inside "%SFM_DIR%".
    popd & pause & goto :eof
)

:: ---------- Put binaries on PATH --------------------------------
set "PATH=%SFM_DIR%;%SFM_DIR%\bin;%PATH%"

:: ---------- Ensure required folders exist ------------------------
if not exist "%VIDEOS_DIR%" (
    echo [ERROR] Input folder "%VIDEOS_DIR%" missing.
    popd & pause & goto :eof
)
if not exist "%SCENES_DIR%" mkdir "%SCENES_DIR%"

:: ---------- Count videos for progress bar ------------------------
for /f %%C in ('dir /b /a-d "%VIDEOS_DIR%\*" ^| find /c /v ""') do set "TOTAL=%%C"
if "%TOTAL%"=="0" (
    echo [INFO] No video files found in "%VIDEOS_DIR%".
    popd & pause & goto :eof
)

echo ==============================================================
echo  Starting GLOMAP pipeline on %TOTAL% video(s) …
echo ==============================================================

set /a IDX=0

for %%V in ("%VIDEOS_DIR%\*.*") do (
    set /a IDX+=1
    call :PROCESS_VIDEO "%%~fV" "%%IDX%%" "%TOTAL%"
)

echo --------------------------------------------------------------
echo  All jobs finished – results are in "%SCENES_DIR%".
echo --------------------------------------------------------------
popd
pause
goto :eof


:PROCESS_VIDEO
:: ----------------------------------------------------------------
::  %1 = full path to video   %2 = current index   %3 = total
:: ----------------------------------------------------------------
setlocal EnableDelayedExpansion

set "VIDEO=%~1"
set "NUM=%~2"
set "TOT=%~3"

for %%I in ("%VIDEO%") do (
    set "BASE=%%~nI"
    set "EXT=%%~xI"
)

echo.
echo [!NUM!/!TOT!] === Processing "!BASE!!EXT!" ===

:: -------- Directory layout for this scene -----------------------
set "SCENE=%SCENES_DIR%\!BASE!"
set "IMG_DIR=!SCENE!\images"
set "SPARSE_DIR=!SCENE!\sparse"

:: -------- Skip if already reconstructed -------------------------
if exist "!SCENE!" (
    echo        • Skipping "!BASE!" – already reconstructed.
    goto :END
)

:: Clean slate ----------------------------------------------------
mkdir "!IMG_DIR!"    >nul
mkdir "!SPARSE_DIR!" >nul

:: -------- 1) Extract every frame --------------------------------
echo        [1/4] Extracting frames …
"%FFMPEG%" -loglevel error -stats -i "!VIDEO!" -qscale:v 2 ^
    "!IMG_DIR!\frame_%%06d.jpg"
if errorlevel 1 (
    echo        × FFmpeg failed – skipping "!BASE!".
    goto :END
)

dir /b "!IMG_DIR!\*.jpg" >nul 2>&1 || (
    echo        × No frames extracted – skipping "!BASE!".
    goto :END
)

:: -------- 2) Feature extraction (COLMAP) -------------------------
echo        [2/4] COLMAP feature_extractor …
"%COLMAP%" feature_extractor ^
    --database_path "!SCENE!\database.db" ^
    --image_path    "!IMG_DIR!" ^
    --ImageReader.single_camera 1 ^
    --SiftExtraction.use_gpu 1 ^
    --SiftExtraction.max_image_size 4096
if errorlevel 1 (
    echo        × feature_extractor failed – skipping "!BASE!".
    goto :END
)

:: -------- 3) Sequential matching (COLMAP) ------------------------
echo        [3/4] COLMAP sequential_matcher …
"%COLMAP%" sequential_matcher ^
    --database_path "!SCENE!\database.db" ^
    --SequentialMatching.overlap 15
if errorlevel 1 (
    echo        × sequential_matcher failed – skipping "!BASE!".
    goto :END
)

:: -------- 4) Sparse reconstruction (GLOMAP) ----------------------
echo        [4/4] GLOMAP mapper …
"%GLOMAP%" mapper ^
    --database_path "!SCENE!\database.db" ^
    --image_path    "!IMG_DIR!" ^
    --output_path   "!SPARSE_DIR!"
if errorlevel 1 (
    echo        × glomap mapper failed – skipping "!BASE!".
    goto :END
)

:: -------- Export TXT **inside the model folder** -----------------
:: Keep TXT next to BIN so Blender can import from sparse\0 directly.
if exist "!SPARSE_DIR!\0" (
    "%COLMAP%" model_converter ^
        --input_path  "!SPARSE_DIR!\0" ^
        --output_path "!SPARSE_DIR!\0" ^
        --output_type TXT >nul
)

:: -------- Export TXT to parent sparse\ (for Blender auto-detect) --
if exist "!SPARSE_DIR!\0" (
    "%COLMAP%" model_converter ^
        --input_path  "!SPARSE_DIR!\0" ^
        --output_path "!SPARSE_DIR!" ^
        --output_type TXT >nul
)

echo        ✓ Finished "!BASE!"  (!NUM!/!TOT!)

:END
endlocal & goto :eof
