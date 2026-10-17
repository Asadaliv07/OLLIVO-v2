# Ollivo — Micro-Feature & Interaction Polish Checklist

## Overview
This document catalogs every small, micro-level interaction, edge-case affordance, state transition, and keyboard/mouse refinement needed to elevate **Ollivo** from an ordinary Flutter desktop utility into a best-in-class, tactile macOS desktop application.

---

## 1. Keyboard Shortcuts & Focus Navigation

- [ ] **`SHORT-01` Global Conversation Navigation**: `⌘+1` through `⌘+6` to switch instantly between Sidebar destinations (`Chat`, `Memory Center`, `Documents`, `Tasks`, `Model Library`, `Settings`).
- [ ] **`SHORT-02` New Conversation**: `⌘+N` starts a fresh conversation immediately, clears active stream state, and focuses the prompt input bar.
- [ ] **`SHORT-03` Conversation Search Overlay**: `⌘+F` opens an in-conversation quick-find field in Chat; `⌘+Shift+F` opens a global cross-conversation search bar.
- [ ] **`SHORT-04` Settings Toggle**: `⌘+,` natively opens the `SettingsView` from any screen in accordance with macOS Apple Human Interface Guidelines.
- [ ] **`SHORT-05` Prompt Input Navigation**:
  - `Enter`: Submits message (when not empty).
  - `Shift+Enter`: Inserts newline without submitting.
  - `Up Arrow` (when input is empty): Loads the user's previously submitted message into the input field for quick editing and re-prompting.
  - `Escape`: Cancels in-flight generation (if streaming) or blurs/clears input focus.
- [ ] **`SHORT-06` Tab-Order Rings**: Every interactive widget (`IconButton`, `ElevatedButton`, `TextField`, `ListTile`) must display a visible 2px Emerald-tinted focus halo when focused via `Tab` key, adhering to macOS keyboard accessibility standards.
- [ ] **`SHORT-07` Modal Escape Dismissal**: Every dialog (`Add Memory`, `New Task`, `Confirmation`, `Modelfile Inspector`) must dismiss on `Escape` key press without submitting or corrupting state.

---

## 2. Text Selection, Clipboard & Copy Behaviors

- [ ] **`CLIP-01` Selective Markdown Text Selection**: Chat messages must use `SelectableText.rich` or selectable Markdown so users can highlight and copy arbitrary sentences, words, or paragraphs without copying the entire bubble.
- [ ] **`CLIP-02` Single-Click Code Block Copy**:
  - Code blocks in assistant messages must feature a top-right header strip displaying language name (`dart`, `json`, `python`) and a copy button (`Copy`).
  - Upon click, the icon transitions to a checkmark (`Copied!`) for 2000ms with haptic/visual feedback before reverting.
- [ ] **`CLIP-03` Copy Raw Message Markdown**: Context menu and message action bar must include "Copy Raw Markdown" for easy pasting into Obsidian, Bear, or GitHub.
- [ ] **`CLIP-04` Formatted Pasting in Input**: Pasting multi-line code or formatted text into the prompt input maintains formatting without stripping newlines or triggering accidental submission.
- [ ] **`CLIP-05` Dragged Text Handling**: Dropping highlighted text directly into the chat prompt input appends text at cursor location.

---

## 3. Tooltips, Labels & Disabled-State Explanations

- [ ] **`TOOL-01` Explanatory Disabled Buttons**:
  - When the Send button is disabled (e.g., input is empty or Ollama is offline), hovering over the button displays a tooltip: `"Enter a prompt to send"` or `"Cannot send: Ollama daemon is offline"`.
  - In `ModelLibraryView`, if a model requires more RAM than available, download button shows: `"Warning: 32B model exceeds physical unified memory headroom"`.
- [ ] **`TOOL-02` Sidebar Icon Tooltips**: When the sidebar is collapsed into icon-only mode, hovering each navigation item shows an instant tooltip (`Chat (⌘1)`, `Memories (⌘2)`, etc.) with a 300ms hover delay.
- [ ] **`TOOL-03` Status Indicator Tooltips**: Hovering the top-bar Ollama status pill displays:
  - Connected: `"Connected to Ollama v0.5.8 on 127.0.0.1:11434"`.
  - Disconnected: `"Ollama is not running. Click to launch local daemon"`.
- [ ] **`TOOL-04` Truncated Item Tooltips**: Any long file name in `DocumentsView`, long conversation title in sidebar, or memory item that is truncated with an ellipsis (`...`) displays its full untruncated text upon mouse hover.

---

## 4. Scroll Physics, Auto-Scroll & Viewport Pinning

- [ ] **`SCRL-01` Smart Auto-Scroll Pinning during Streaming**:
  - While tokens are actively streaming, the chat auto-scrolls down to keep the latest line visible.
  - **Critical Rule**: If the user manually scrolls up by more than 40px to read previous paragraphs, streaming auto-scroll must immediately unpin so the view does not jerk out from under the user's cursor.
  - A subtle floating button appears: `"Scroll to bottom ↓"`. Clicking it immediately re-pins to bottom.
- [ ] **`SCRL-02` Native macOS Scroll Physics**:
  - Configure `BouncingScrollPhysics()` across all desktop lists.
  - Custom dark scrollbar thumb that fades out when idle and darkens on hover, matching macOS NSScrollView aesthetics.
- [ ] **`SCRL-03` Mouse Wheel & Trackpad Inertia**: Ensure smooth 120Hz ProMotion trackpad momentum scrolling without stutter across message histories with 50+ messages.

---

## 5. Input Field Micro-Interactions

- [ ] **`INP-01` Auto-Expanding Prompt Area**:
  - Prompt input begins at a compact 1-line height (44px).
  - As the user types multiple lines, the container expands smoothly up to 6 lines (approx. 160px).
  - Beyond 6 lines, the text area locks height and enables internal vertical scrolling.
- [ ] **`INP-02` Clear Input Affordance**: A subtle `✕` icon appears inside the input field when text is present to allow 1-click clearing.
- [ ] **`INP-03` Drag-and-Drop Document Dropzone Overlay**:
  - Dragging a file (`.pdf`, `.txt`, `.md`, `.docx`) over the chat window highlights the input area with an Emerald dashed border: `"Drop file here to add to conversation context"`.
  - Dropping the file auto-attaches it as a chip above the text input.
- [ ] **`INP-04` Attached Context Chips**:
  - Attached documents or tasks appear as removable pills above the text input with filename, size, and a remove `✕` button.
  - Hovering chip shows file path and token estimate.

---

## 6. Feedback, Toasts & Confirmation Safeguards

- [ ] **`FDBK-01` Non-Intrusive Toast System**:
  - Replace blocking SnackBars that cover the bottom input area with elegant, top-right floating toast banners (`OllivoToast`).
  - Supports types: `Success` (Emerald), `Warning` (Amber), `Error` (Crimson), `Info` (Cyan).
  - Automatically dismisses after 3.5 seconds with an optional `Undo` action button.
- [ ] **`FDBK-02` Destructive Action Confirmations**:
  - Deleting a conversation, clearing all memories, or deleting an ingested document must require an explicit confirmation modal.
  - Modal must feature: destructive Red button, cancel button focused by default, and a `"Do not ask again for conversations"` checkbox preference.
- [ ] **`FDBK-03` In-Flight Cancellation Feedback**:
  - When the user clicks the square "Stop" button during active token streaming, Ollivo immediately stops reading the stream socket, flushes the partial text to SQLite, and updates the message status pill to `"Interrupted by user"`.
- [ ] **`FDBK-04` Model Download Progress Bar**:
  - In `ModelLibraryView` and the top bar, active downloads must display percentage, downloaded/total megabytes (`1.4 GB / 4.7 GB`), and download speed (`45 MB/s`).
  - If a download fails or is cancelled, clean up partial blobs to prevent phantom disk storage usage.

---

## 7. Context Menus (macOS Right-Click)

- [ ] **`CTX-01` Chat Message Context Menu**:
  - Right-clicking any chat message opens a native desktop context menu:
    - *Copy Text*
    - *Copy Raw Markdown*
    - *Add to Memories*
    - *Create Task from This*
    - *Branch Conversation Here* (Assistant messages)
    - *Delete Message*
- [ ] **`CTX-02` Sidebar Conversation Item Context Menu**:
  - Right-clicking a conversation in the history list:
    - *Rename Conversation*
    - *Pin to Top*
    - *Export as Markdown (.md)*
    - *Duplicate*
    - *Delete Conversation*
- [ ] **`CTX-03` Memory Card Context Menu**:
  - *Edit Fact*
  - *Change Category*
  - *Copy to Clipboard*
  - *Delete Memory*
- [ ] **`CTX-04` Document Item Context Menu**:
  - *View Extracted Chunks*
  - *Re-Index Document*
  - *Reveal in Finder*
  - *Remove from Ollivo*

---

## 8. Hover, Pressed & Animation States

- [ ] **`HOV-01` Interactive Button Elevating States**:
  - Primary emerald action buttons transition background color smoothly over 150ms (`Color(0xFF10B981)` to `Color(0xFF059669)` on hover).
  - Subtle mouse cursor pointer (`SystemMouseCursors.click`) on all clickable elements.
- [ ] **`HOV-02` Sidebar Item Hover**:
  - Inactive sidebar navigation tiles display a subtle translucent white highlight (`Colors.white.withOpacity(0.04)`) on hover.
  - Active navigation item displays an emerald left indicator strip (3px wide) and high-contrast icon.
- [ ] **`HOV-03` Card Hover Glow**:
  - Model cards and Memory cards have a 1px border that subtly illuminates from `Colors.white10` to `Color(0x3310B981)` when hovered.
- [ ] **`HOV-04` Streaming Token Pulsing Indicator**:
  - While waiting for the first token (Time To First Token), display a three-dot breathing pulse animation (`...`) styled in muted emerald.

---

## 9. Alignment, Spacing & Typography Details

- [ ] **`TYP-01` Monospace Code Typography**:
  - Code blocks, token speeds, file sizes, and memory hex values render in a clean monospace font (`JetBrains Mono`, `SF Mono`, or `Menlo`).
- [ ] **`TYP-02` Consistent Date & Timestamp Formatting**:
  - Timestamps across Chat, Tasks, and Memories must follow consistent humanized formatting:
    - Today: `Today at 2:45 PM`
    - Yesterday: `Yesterday at 11:20 AM`
    - Older: `Oct 8, 2026 • 9:15 AM`
- [ ] **`TYP-03` Numerical Alignment in Tables & Stats**:
  - File sizes (`MB`, `GB`), token counts, and token speeds (`tok/s`) must be right-aligned or tabular-spaced to prevent visual layout shifts.
- [ ] **`TYP-04` Zero Overflow Safeguards**:
  - All title rows and cards must wrap text or apply `TextOverflow.ellipsis` with strict bounding constraints. No `RenderFlex overflowed` red/yellow bars under any window resizing condition.

---

## 10. macOS Native Integration Details

- [ ] **`MACU-01` Window Traffic Lights Margin**:
  - Ensure the custom top header bar respects the native macOS traffic lights (Close, Minimize, Zoom buttons) with a minimum left padding of 78px when the window is in normal windowed mode.
- [ ] **`MACU-02` Fullscreen State Handling**:
  - When the app enters native macOS fullscreen mode, reduce header padding smoothly so controls do not float awkwardly.
- [ ] **`MACU-03` Window Resize Grippers & Minimum Constraints**:
  - Minimum window width locked to `900px`, minimum height locked to `600px` via `window_manager` to prevent UI breakage on cramped displays.
- [ ] **`MACU-04` Native Reveal in Finder**:
  - In `DocumentsView` and `SettingsView`, provide a "Reveal in Finder" button that opens macOS Finder directly focused on the local document or SQLite database file.
