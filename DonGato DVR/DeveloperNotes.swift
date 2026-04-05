//
//  DeveloperNotes.swift
//  DonGato DVR
//
//  Created by Michael Fluharty on 4/5/26.
//

/*

 ═══════════════════════════════════════════════════════════════════
 DONGATO DVR — DEVELOPER NOTES
 ═══════════════════════════════════════════════════════════════════

 Bundle ID: com.sigfigprd.DonGato-DVR
 License: GPL v3 — Share and share alike with attribution required
 GitHub: fluhartyml/DonGato-DVR
 Engineered with Claude by Anthropic

 ═══════════════════════════════════════════════════════════════════
 R&D ROADMAP
 ═══════════════════════════════════════════════════════════════════

 v1.0 — CURRENT BUILD
 --------------------
 - VCR-style capture interface with retro faceplate
 - AVCaptureSession + AVAssetWriter recording pipeline
 - UVC external capture device support (Elgato 4K S, etc.)
 - Built-in camera fallback (Camcorder Mode) with front/rear flip
 - Real-time scene detection: black frame, scene change, audio gap
 - Manual smart-snap split (press-and-hold brackets the transition)
 - Rolling frame score buffer (3 seconds, brightness/histogram/audio)
 - Dual tape counters (ELAPSED green, SEGMENT orange)
 - Quality presets: SD 480p, HD 720p, 1080p, 4K
 - Content modes: CONTINUOUS (broadcast) and CHAPTERS (split)
 - Detection presets: Broadcast TV, Short-form Clips, Home Video, Custom
 - Post-recording split into individual segment files
 - Post-recording transcode (Original, Half, Quarter, Custom target)
 - Recordings library with segment breakdown and actions
 - SwiftData persistence (Recording, Segment models)
 - About sheet with DRM/DMCA disclaimer and tech credits
 - Claude easter egg (sparkle animation on long-press)
 - App icon: Don Gato cat face on CRT test pattern

 v1.1 — PLANNED
 ---------------
 - AVCaptureMultiCamSession dual-camera recording
   - Composited PiP (single file, front camera in corner like FaceTime)
   - Separate streams (two files for post-production, Final Cut, etc.)
   - Both (composited preview + raw separate streams saved)
 - EULA integration for App Store submission
 - iOS 18+ TabView syntax (raise deployment target from 17 to 18)
 - Error alerts shown to user for transcode/split failures
 - Disk space check before recording
 - SceneDetector.reset() called between recordings

 v1.2 — FUTURE
 ---------------
 - VHS scanline overlay toggle for retro camcorder aesthetic
 - Recording title editing (tap to rename)
 - iCloud Drive export for recordings
 - Share sheet integration (export segments to Files, AirDrop, etc.)
 - Thumbnail previews in recordings list
 - Playback of recordings within the app
 - Segment reordering and manual trim
 - Custom transcode target file size ("fit in X GB")

 v2.0 — LONG TERM
 ------------------
 - FFmpeg integration for advanced transcoding codecs
 - Cross-platform (iPadOS, macOS via Catalyst or native)
 - Scheduled recording (start/stop at set times)
 - Commercial skip mode (auto-remove detected commercials)
 - Chapter markers in MOV metadata
 - Batch transcode queue
 - Network streaming input (RTSP, HLS sources)

 ═══════════════════════════════════════════════════════════════════
 SHAKEDOWN CHECKLIST — QA TESTING
 ═══════════════════════════════════════════════════════════════════

 APP LAUNCH & LIFECYCLE
 ----------------------
 [ ] App launches with three tabs: VCR, Recordings, About
 [ ] All three tabs accessible during recording
 [ ] Device connection status updates on launch
 [ ] SwiftData models persist across app sessions
 [ ] App terminates cleanly when force-quit mid-recording

 VCR TAB — PREVIEW AREA
 -----------------------
 [ ] Live video preview displays when device connected
 [ ] DonGato logo at 60% opacity when NO device connected
 [ ] Preview background is pure black
 [ ] "NO SIGNAL" in red text when device disconnected
 [ ] "REC" indicator with red dot appears top-left when recording
 [ ] "CAMCORDER" label in orange when using built-in camera
 [ ] Camera flip button appears only in camcorder mode
 [ ] Camera flip button disabled during recording
 [ ] Front/rear camera toggle works correctly
 [ ] Device name updates on camera flip

 VCR TAB — DEVICE NAME
 ----------------------
 [ ] Green monospaced text at top of faceplate
 [ ] External UVC device shows actual device name
 [ ] Built-in shows "Camcorder — Front" or "Camcorder — Rear"
 [ ] "No Camera Available" when no device found

 VCR TAB — TAPE COUNTERS
 ------------------------
 [ ] ELAPSED counter in green, SEGMENT counter in orange
 [ ] Both start at 00:00 when recording begins
 [ ] SEGMENT resets to 00:00 after each split
 [ ] Counters update every 0.1 seconds during recording
 [ ] Counters freeze when recording stops
 [ ] Format switches from MM:SS to H:MM:SS after 1 hour

 VCR TAB — SPLIT POINT INDICATORS
 ---------------------------------
 [ ] Icons appear only when splits detected
 [ ] Up to 20 most recent split icons shown
 [ ] Black Frame = purple rectangle
 [ ] Scene Change = cyan film
 [ ] Audio Gap = yellow speaker-slash
 [ ] Manual = green hand-tap
 [ ] No indicator row when zero splits

 VCR TAB — CONTENT MODE
 -----------------------
 [ ] CONTINUOUS and CHAPTERS buttons
 [ ] Selected = white text, blue background
 [ ] Unselected = gray text, clear background
 [ ] Mode saved with recording metadata

 VCR TAB — QUALITY SELECTOR
 ---------------------------
 [ ] Four buttons: SD (480p), HD (720p), 1080p, 4K
 [ ] Selected = white text, orange background
 [ ] Defaults to 1080p on launch
 [ ] Quality change reconfigures capture session in camcorder mode
 [ ] Quality buttons disabled during recording

 VCR TAB — RECORD/STOP BUTTON
 -----------------------------
 [ ] Red record icon when idle, white stop icon when recording
 [ ] REC button disabled when no device connected
 [ ] Tapping REC starts recording, creates MOV file
 [ ] Tapping STOP shows confirmation alert
 [ ] Alert: "Stop Recording?" with "Stop & Process" and "Cancel"
 [ ] Cancel keeps recording active
 [ ] Stop & Process creates SwiftData entry with segments
 [ ] File saved to Documents/Recordings/DonGato_YYYY-MM-DD_HHmmss.mov

 VCR TAB — SPLIT BUTTON (PRESS AND HOLD)
 -----------------------------------------
 [ ] Yellow scissors icon when idle
 [ ] Disabled (30% opacity) when not recording
 [ ] Press: icon scales to 1.3x, turns red, text changes to "HOLD"
 [ ] Release: triggers smart snap search
 [ ] Smart snap searches press time -0.5s to release time +0.5s
 [ ] Best frame scored by: darkness 40% + scene change 40% + silence 20%
 [ ] If best score > 0.15, uses that frame; otherwise uses midpoint
 [ ] SEGMENT counter resets after split
 [ ] Animation: 0.15s ease-in-out on press/release

 VCR TAB — DETECTION SETTINGS
 -----------------------------
 [ ] Orange button opens settings sheet
 [ ] Sheet has "Done" button to dismiss

 DETECTION SETTINGS — PRESETS
 -----------------------------
 [ ] Four presets: Broadcast TV, Short-form Clips, Home Video, Custom
 [ ] Checkmark shows on selected preset
 [ ] Tapping preset applies its settings
 [ ] Any manual slider change switches to Custom
 [ ] Broadcast TV: black frame + audio gap enabled
 [ ] Short-form: black frame + scene change enabled
 [ ] Home Video: scene change + audio gap enabled

 DETECTION SETTINGS — BLACK FRAME
 ----------------------------------
 [ ] Toggle enables/disables
 [ ] Darkness Threshold slider (Lenient ↔ Strict)
 [ ] Minimum Duration slider (Short ↔ Long)
 [ ] Sliders hidden when disabled
 [ ] Duration range: 0-2 seconds
 [ ] Detects sustained dark frames, splits when duration met
 [ ] Timer resets when brightness returns to normal

 DETECTION SETTINGS — SCENE CHANGE
 -----------------------------------
 [ ] Toggle enables/disables
 [ ] Sensitivity slider (Less Splits ↔ More Splits)
 [ ] Slider hidden when disabled
 [ ] Uses 64-bin histogram comparison between frames
 [ ] First frame has no comparison, no split possible
 [ ] Large visual changes trigger split

 DETECTION SETTINGS — AUDIO GAP
 --------------------------------
 [ ] Toggle enables/disables
 [ ] Silence Threshold slider (Quiet ↔ Silent)
 [ ] Gap Duration slider (Short ↔ Long)
 [ ] Sliders hidden when disabled
 [ ] Duration range: 0-4 seconds
 [ ] RMS audio level measured per sample buffer
 [ ] Sustained silence triggers split

 DETECTION SETTINGS — MANUAL SPLIT
 -----------------------------------
 [ ] Toggle enables/disables
 [ ] No sliders
 [ ] Footer: "Tap the scissors button during recording..."

 RECORDINGS TAB
 ---------------
 [ ] Empty state: "No recordings yet. Connect a capture device and hit REC."
 [ ] Recordings sorted newest first
 [ ] Each recording shows: title, quality badge, duration, file size, content mode, date
 [ ] Segment breakdown with index, duration, detection type
 [ ] Split button (disabled if no segments or during transcode)
 [ ] Transcode menu: Original, Half Size, Quarter Size, Custom
 [ ] Transcode button disabled during active transcode
 [ ] Processing section with progress bar during transcode
 [ ] Swipe-to-delete removes recording and file from disk
 [ ] Deletion animated

 SPLIT FUNCTIONALITY
 --------------------
 [ ] Creates "Split_[title]" subdirectory
 [ ] Each segment exported as Segment_001.mov, Segment_002.mov, etc.
 [ ] Segments < 0.5 seconds skipped
 [ ] AVAssetExportSession passthrough preset (no re-encoding)
 [ ] Progress updates: "Exporting segment X of Y..."
 [ ] Segment fileURL and isExported updated on completion

 TRANSCODE FUNCTIONALITY
 ------------------------
 [ ] Original = 1.0x scale, no compression
 [ ] Half = 0.5x resolution
 [ ] Quarter = 0.25x resolution
 [ ] Output: "Transcoded_[filename]" in same directory
 [ ] H.264 video, AAC stereo 128kbps audio
 [ ] Progress bar updates in real time
 [ ] Existing output file deleted before writing

 ABOUT TAB
 ----------
 [ ] DonGato logo 120x120 with rounded corners and shadow
 [ ] "DonGato DVR" title in 32pt monospaced bold
 [ ] Version and build number displayed
 [ ] Legal notice with DRM/DMCA disclaimer
 [ ] "By using DonGato DVR, you agree you own the content..."
 [ ] Five technology credits with descriptions
 [ ] Tapping Claude credit opens easter egg sheet
 [ ] Easter egg: purple sparkle pulse, "Hello from Claude", "Anthropic"
 [ ] GPL v3 license section
 [ ] Michael Fluharty / sigfigprd credits

 CAPTURE PIPELINE
 -----------------
 [ ] External UVC device prioritized over built-in camera
 [ ] Built-in camera fallback with position selection
 [ ] Audio: external device audio first, then built-in mic
 [ ] AVAssetWriter: H.264 video, AAC audio, MOV container
 [ ] Writer starts session on first sample buffer
 [ ] Video and audio appended if input ready for more data
 [ ] Recording timer: 0.1 second interval
 [ ] flipCamera() stops preview, reconfigures session, restarts
 [ ] changeQuality() sets session preset (vga/720/1080/4K)

 SCENE DETECTION — GENERAL
 --------------------------
 [ ] Detection runs on background queues (video + audio separate)
 [ ] 2-second minimum gap between auto-detected splits
 [ ] Manual splits NOT subject to 2-second minimum
 [ ] Frame scores buffered for 3 seconds (rolling window)
 [ ] Each frame scored: brightness, histogram diff, audio level
 [ ] Brightness sampled every 16th pixel
 [ ] Histogram: 64 bins, sampled every 8th pixel
 [ ] Audio RMS: sampled ~512 frames per buffer

 EDGE CASES TO TEST
 --------------------
 [ ] Record with no audio input (video only)
 [ ] Very short recording (< 1 second)
 [ ] Very long recording (10+ minutes)
 [ ] Rapid split button mashing (many splits close together)
 [ ] Change detection settings mid-recording
 [ ] Switch tabs during recording
 [ ] Background app during recording
 [ ] Delete recording while transcode in progress
 [ ] Transcode a recording with zero segments
 [ ] Split a recording with one segment
 [ ] Cover camera lens (should trigger black frame detection)
 [ ] Complete silence audio (should trigger audio gap)
 [ ] Quick scene cuts (should trigger scene change)
 [ ] Device disconnect during preview (not during recording)
 [ ] Low disk space during recording
 [ ] Multiple recordings back-to-back without app restart

 KNOWN ISSUES / BUGS TO WATCH
 ------------------------------
 [ ] SceneDetector.reset() not called between recordings — buffer carries over
 [ ] Transcode/split errors logged to console but no user-facing alert
 [ ] Device disconnect mid-recording not handled gracefully
 [ ] Custom transcode quality doesn't accept user input (hardcoded 0.5x)
 [ ] No disk space check before recording
 [ ] No undo for deleted recordings

 ═══════════════════════════════════════════════════════════════════
 ARCHITECTURE
 ═══════════════════════════════════════════════════════════════════

 DonGato_DVRApp.swift      — App entry, ModelContainer, environment objects
 ContentView.swift          — TabView (VCR, Recordings, About)
 VCRView.swift              — Main recording interface, preview, faceplate
 VideoPreviewContainer.swift — Platform-specific AVCaptureVideoPreviewLayer
 TapeCounterView.swift      — Dual elapsed/segment counters
 TransportControlsView.swift — Record/Stop + Split buttons
 DetectionSettingsView.swift — Toggles, sliders, presets for scene detection
 RecordingsListView.swift   — Recording library with split/transcode actions
 AboutView.swift            — Credits, legal, easter egg

 CaptureService.swift       — AVCaptureSession, AVAssetWriter, device management
 SceneDetector.swift        — Frame analysis, audio analysis, smart snap
 TranscodeService.swift     — Video splitting and re-encoding

 Recording.swift            — SwiftData model for recorded sessions
 Segment.swift              — SwiftData model for split segments

 ═══════════════════════════════════════════════════════════════════

*/
