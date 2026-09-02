#!/usr/bin/env python3
"""
Recorder App (Windows version) — GUI wrapper around a record + OCR-summary
workflow, adapted from the Linux (Cinnamon/XFCE) recorder-app.py.

Three fields (Title / Field 2 / Field 3) combine into the output filename.
Start button begins recording system audio (via ffmpeg + VB-Audio Virtual
Cable) + a rolling screenshot buffer (via mss) in the background; Stop runs
OCR (tesseract) on the latest screenshot and writes a summary. A Cleanup
button lets you clear out old screenshots so the pic folder doesn't grow
unbounded.

Differences from the Linux version:
- Audio capture uses ffmpeg's DirectShow (dshow) input instead of
  PulseAudio, pointed at "CABLE Output (VB-Audio Virtual Cable)". For this
  to actually capture anything, Windows' default *output* device must be
  set to "CABLE Input (VB-Audio Virtual Cable)" (Settings > System > Sound)
  for the entire duration of the recording — same idea as the dummy
  headphone-jack trick used on Linux for silent capture.
- Screenshots use the `mss` Python library (pip install mss) instead of
  shelling out to ImageMagick's `import -window root`, since ImageMagick's
  X11 screenshot tool doesn't exist on Windows. mss is a direct Python call,
  no subprocess needed.
- Tesseract OCR and the Tkinter GUI are unchanged — both are cross-platform.

Requires: ffmpeg (on PATH), tesseract (on PATH), the `mss` pip package, and
(strongly recommended — see run_ocr() below) the `Pillow` pip package for
image preprocessing: pip install mss Pillow

--- OCR reliability notes (Sept 2026) ---
The original build_summary() ran tesseract directly on the raw screenshot,
which is a capture of the ENTIRE virtual screen (all monitors). That's a
huge, busy image — desktop icons, taskbar, other windows — and tesseract's
default settings assume a clean page of text, not a cluttered screen with
one small relevant region. That mismatch is why summaries kept coming back
"unknown / not detected" even when the on-screen reference was perfectly
readable to a human.

Two fixes applied below:
1. run_ocr() now preprocesses the screenshot with Pillow before OCR:
   grayscale, 2x upscale, and an autocontrast + contrast boost pass. This
   alone typically makes small anti-aliased UI text much more legible to
   tesseract. It also switches to `--psm 11` (sparse text mode), which is
   built for exactly this situation — scattered text in no particular
   layout — instead of the default full-page-layout mode.
2. OCR_CROP_BOX (below) lets you crop to just the screen region where the
   chapter/verse + timestamp actually shows up, if that's ever the same
   spot session to session. This is the single biggest accuracy win
   possible, since tesseract then only has to read a couple of words
   instead of the whole desktop — but it's left off (None) by default
   since different source apps may show it in different places. Figure
   out the pixel box with any screenshot tool that reports coordinates
   (Snip & Sketch's Rectangle mode, or mspaint's cursor readout) and set
   it below if it turns out to be consistent for you.

These are best-effort, standard-practice improvements — they weren't
tuned against a real sample screenshot from this setup (only a blind fix
based on well-known tesseract behavior), so keep an eye on the next few
_stopped-at.txt files and report back if it's still missing things — the
regexes below can be tightened further once we see real OCR output.
"""

import os
import re
import glob
import subprocess
import threading
import time
import tkinter as tk
from tkinter import ttk, messagebox

import mss
import mss.tools

try:
    from PIL import Image, ImageOps, ImageEnhance
    HAVE_PIL = True
except ImportError:
    HAVE_PIL = False

# ---- Configuration ----
# Adjust these to wherever you want output stored on this machine.
MP3_DIR = r"\\192.168.86.23\bigstorage\mp3"
PIC_DIR = r"\\192.168.86.23\bigstorage\pic"

# Exact device name as reported by:
#   ffmpeg -list_devices true -f dshow -i dummy
AUDIO_DEVICE = "CABLE Output (VB-Audio Virtual Cable)"

SCREENSHOT_INTERVAL = 20  # seconds
KEEP_SCREENSHOTS = 9      # ~3 minutes of rolling buffer per session

# Optional (left, top, right, bottom) pixel box to crop screenshots to
# before OCR, if the chapter/verse + timestamp reliably appears in the
# same spot on your screen. None = OCR the full screenshot (current
# default). See the OCR reliability notes in the module docstring above.
OCR_CROP_BOX = None


NOISE_SNIPPETS = [
    "field 2", "field 3", "title", "auto-stop", "minutes (blank",
    "start recording", "clean up old", "stopped-at", "screenshot:",
    "audio file:", "recorder", "e.g. chapter", "e.g. verse",
    "idle.", "done. saved", "heidi", "willm",
]

def strip_noise(text):
    """Drop lines that are almost certainly our own app/window chrome."""
    kept = []
    for line in text.splitlines():
        low = line.lower().strip()
        if not low:
            continue
        if any(snip in low for snip in NOISE_SNIPPETS):
            continue
        kept.append(line)
    return "\n".join(kept)

def sanitize(text):
    """Make a string filesystem-safe for use in a filename."""
    text = text.strip()
    text = re.sub(r"[^\w\s-]", "", text)
    text = re.sub(r"\s+", "-", text)
    return text or "untitled"


class RecorderApp:
    def __init__(self, root):
        self.root = root
        root.title("Recorder")
        root.geometry("420x460")
        root.attributes("-topmost", True)
        root.resizable(False, False)

        self.recording = False
        self.ffmpeg_proc = None
        self.shot_thread = None
        self.stop_event = threading.Event()
        self.start_time = None
        self.basename = None
        self.timestamp = None
        self.timer_job = None

        pad = {"padx": 10, "pady": 6}

        ttk.Label(root, text="Title", font=("", 10, "bold")).pack(anchor="w", **pad)
        self.title_entry = ttk.Entry(root, width=45)
        self.title_entry.pack(padx=10)

        ttk.Label(root, text="Field 2 (e.g. chapter, artist)", font=("", 10, "bold")).pack(anchor="w", **pad)
        self.field2_entry = ttk.Entry(root, width=45)
        self.field2_entry.pack(padx=10)

        ttk.Label(root, text="Field 3 (e.g. verse, album — optional)", font=("", 10, "bold")).pack(anchor="w", **pad)
        self.field3_entry = ttk.Entry(root, width=45)
        self.field3_entry.pack(padx=10)

        limit_frame = ttk.Frame(root)
        limit_frame.pack(padx=10, pady=(4, 0), anchor="w")
        ttk.Label(limit_frame, text="Auto-stop after:").pack(side="left")
        self.duration_var = tk.StringVar(value="60")
        ttk.Entry(limit_frame, textvariable=self.duration_var, width=6).pack(side="left", padx=6)
        ttk.Label(limit_frame, text="minutes (blank = no limit)").pack(side="left")

        btn_frame = ttk.Frame(root)
        btn_frame.pack(pady=16)

        self.start_btn = ttk.Button(btn_frame, text="Start Recording", command=self.start_recording)
        self.start_btn.grid(row=0, column=0, padx=6)

        self.stop_btn = ttk.Button(btn_frame, text="Stop", command=self.stop_recording, state="disabled")
        self.stop_btn.grid(row=0, column=1, padx=6)

        self.cleanup_btn = ttk.Button(root, text="Clean Up Old Screenshots...", command=self.open_cleanup_dialog)
        self.cleanup_btn.pack(pady=(0, 10))

        sep = ttk.Separator(root, orient="horizontal")
        sep.pack(fill="x", padx=10, pady=6)

        # Big elapsed-time readout
        self.elapsed_var = tk.StringVar(value="00:00")
        self.elapsed_label = ttk.Label(root, textvariable=self.elapsed_var, font=("", 28, "bold"), anchor="center")
        self.elapsed_label.pack(pady=(4, 0))

        # Progress bar: determinate (fills toward auto-stop time) when a
        # duration limit is set, indeterminate (pulsing back and forth)
        # when there's no limit to measure progress against.
        self.progress = ttk.Progressbar(root, orient="horizontal", length=380, mode="determinate", maximum=100)
        self.progress.pack(padx=10, pady=(6, 2))

        self.remaining_var = tk.StringVar(value="")
        self.remaining_label = ttk.Label(root, textvariable=self.remaining_var, anchor="center")
        self.remaining_label.pack(pady=(0, 6))

        self.status_var = tk.StringVar(value="Idle. Fill in the fields above and click Start.")
        self.status_label = ttk.Label(root, textvariable=self.status_var, wraplength=390, justify="left")
        self.status_label.pack(padx=10, pady=6, anchor="w")

        self.summary_var = tk.StringVar(value="")
        self.summary_label = ttk.Label(root, textvariable=self.summary_var, wraplength=390, justify="left", foreground="#2b6")
        self.summary_label.pack(padx=10, pady=6, anchor="w")

        root.protocol("WM_DELETE_WINDOW", self.on_close)

    # ---- Recording control ----

    def start_recording(self):
        if self.recording:
            return

        title = sanitize(self.title_entry.get())
        field2 = sanitize(self.field2_entry.get())
        field3 = sanitize(self.field3_entry.get())

        parts = [p for p in [title, field2, field3] if p and p != "untitled"]
        if not parts:
            messagebox.showwarning("Missing info", "Please enter at least a Title.")
            return

        duration_text = self.duration_var.get().strip()
        self.max_duration_secs = None
        if duration_text:
            try:
                self.max_duration_secs = float(duration_text) * 60
                if self.max_duration_secs <= 0:
                    raise ValueError
            except ValueError:
                messagebox.showwarning("Invalid duration", "Auto-stop minutes must be a positive number, or leave it blank for no limit.")
                return

        self.basename = "_".join(parts)
        self.timestamp = time.strftime("%Y-%m-%d_%H%M")

        os.makedirs(MP3_DIR, exist_ok=True)
        os.makedirs(PIC_DIR, exist_ok=True)

        audio_file = self.audio_path()

        try:
            self.ffmpeg_proc = subprocess.Popen(
                ["ffmpeg", "-y", "-f", "dshow", "-i", f"audio={AUDIO_DEVICE}",
                 "-ac", "2", "-ab", "192k", audio_file],
                stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                creationflags=subprocess.CREATE_NO_WINDOW
            )
        except FileNotFoundError:
            messagebox.showerror("ffmpeg not found", "ffmpeg is not installed or not on PATH.")
            return

        self.stop_event.clear()
        self.shot_thread = threading.Thread(target=self.screenshot_loop, daemon=True)
        self.shot_thread.start()

        self.recording = True
        self.start_time = time.time()
        self.summary_var.set("")
        self.start_btn.config(state="disabled")
        self.stop_btn.config(state="normal")
        self.title_entry.config(state="disabled")
        self.field2_entry.config(state="disabled")
        self.field3_entry.config(state="disabled")

        if self.max_duration_secs:
            self.progress.config(mode="determinate", maximum=100)
            self.progress["value"] = 0
            mins = self.max_duration_secs / 60
            self.status_var.set(f"Recording will auto-stop after {mins:g} minutes.")
        else:
            self.progress.config(mode="indeterminate")
            self.progress.start(50)
            self.remaining_var.set("No time limit set")

        self.tick()

    def screenshot_loop(self):
        # mss instances aren't guaranteed thread-safe across long-lived reuse
        # in every environment, so create a fresh one inside the loop thread.
        with mss.mss() as sct:
            monitor = sct.monitors[0]  # index 0 = full virtual screen (all monitors)
            while not self.stop_event.is_set():
                ts = time.strftime("%H%M%S")
                shot_path = os.path.join(PIC_DIR, f"{self.basename}_{self.timestamp}_{ts}.png")
                try:
                    img = sct.grab(monitor)
                    mss.tools.to_png(img.rgb, img.size, output=shot_path)
                except Exception:
                    pass

                existing = sorted(
                    glob.glob(os.path.join(PIC_DIR, f"{self.basename}_{self.timestamp}_*.png")),
                    key=os.path.getmtime, reverse=True
                )
                for old in existing[KEEP_SCREENSHOTS:]:
                    try:
                        os.remove(old)
                    except OSError:
                        pass

                self.stop_event.wait(SCREENSHOT_INTERVAL)

    def audio_path(self):
        return os.path.join(MP3_DIR, f"{self.basename}_{self.timestamp}.mp3")

    def tick(self):
        if not self.recording:
            return
        elapsed_secs = time.time() - self.start_time
        elapsed = int(elapsed_secs)
        mins, secs = divmod(elapsed, 60)
        self.elapsed_var.set(f"{mins:02d}:{secs:02d}")

        if self.max_duration_secs and elapsed_secs >= self.max_duration_secs:
            self.progress["value"] = 100
            self.status_var.set("Reached time limit — stopping automatically...")
            self.root.update_idletasks()
            self.stop_recording()
            return

        if self.max_duration_secs:
            pct = min(100, (elapsed_secs / self.max_duration_secs) * 100)
            self.progress["value"] = pct
            remaining = int(self.max_duration_secs - elapsed_secs)
            rmins, rsecs = divmod(max(remaining, 0), 60)
            self.remaining_var.set(f"Auto-stop in {rmins:02d}:{rsecs:02d}")

        self.status_var.set(f"Recording \"{self.basename}\"...\n"
                             f"You can minimize this window and walk away — it keeps running.")
        self.timer_job = self.root.after(1000, self.tick)

    def stop_recording(self):
        if not self.recording:
            return

        self.status_var.set("Stopping and analyzing last screenshot...")
        self.root.update_idletasks()

        if self.timer_job:
            self.root.after_cancel(self.timer_job)

        self.stop_event.set()
        if self.shot_thread:
            self.shot_thread.join(timeout=5)

        self.progress.stop()
        self.progress.config(mode="determinate")
        self.progress["value"] = 0
        self.remaining_var.set("")
        self.elapsed_var.set("00:00")

        if self.ffmpeg_proc:
            try:
                # ffmpeg on Windows doesn't respond to SIGTERM the way it
                # does on Linux; send 'q' on stdin isn't available since we
                # redirected DEVNULL, so terminate() is the practical option.
                self.ffmpeg_proc.terminate()
                self.ffmpeg_proc.wait(timeout=10)
            except Exception:
                try:
                    self.ffmpeg_proc.kill()
                except Exception:
                    pass

        self.recording = False
        self.start_btn.config(state="normal")
        self.stop_btn.config(state="disabled")
        self.title_entry.config(state="normal")
        self.field2_entry.config(state="normal")
        self.field3_entry.config(state="normal")

        try:
            summary = self.build_summary()
        except Exception as e:
            import traceback
            traceback.print_exc()
            summary = f"Done, but summary generation failed: {e}\n(see terminal for the full traceback)"

        self.status_var.set("Idle. Fill in the fields above and click Start.")
        self.summary_var.set(summary)

    def run_ocr(self, image_path):
        """
        Preprocess the screenshot before handing it to tesseract, then
        return the raw OCR text. See the OCR reliability notes at the top
        of this file for why this exists.
        """
        ocr_target = image_path

        if HAVE_PIL:
            img = Image.open(image_path).convert("L")  # grayscale
            if OCR_CROP_BOX:
                img = img.crop(OCR_CROP_BOX)
            w, h = img.size
            img = img.resize((w * 2, h * 2), Image.LANCZOS)
            img = ImageOps.autocontrast(img)
            img = ImageEnhance.Contrast(img).enhance(1.5)
            ocr_target = image_path + ".ocr-tmp.png"
            img.save(ocr_target)

        try:
            result = subprocess.run(
                ["tesseract", ocr_target, "stdout", "--psm", "11"],
                stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True,
                timeout=30, creationflags=subprocess.CREATE_NO_WINDOW
            )
            return result.stdout
        finally:
            if ocr_target != image_path:
                try:
                    os.remove(ocr_target)
                except OSError:
                    pass

    def build_summary(self):
        pattern = os.path.join(PIC_DIR, f"{self.basename}_{self.timestamp}_*.png")
        shots = sorted(glob.glob(pattern), key=os.path.getmtime, reverse=True)
        audio_file = self.audio_path()
        summary_file = os.path.join(MP3_DIR, f"{self.basename}_{self.timestamp}_stopped-at.txt")

        player_time = "unknown"
        reference = "not detected"
        latest_shot_name = "none"
        ocr_note = ""

        if not HAVE_PIL:
            ocr_note += " (Pillow not installed - run: pip install Pillow - for much better OCR accuracy)"

        if shots:
            latest_shot = shots[0]
            latest_shot_name = os.path.basename(latest_shot)
            try:
                ocr_text = self.run_ocr(latest_shot)

                clean_text = strip_noise(ocr_text)

                time_match = re.search(r"\b([0-9]{1,2}:[0-9]{2}(?::[0-9]{2})?)\b", clean_text)
                if time_match:
                    player_time = time_match.group(1)

                ref_match = re.search(
                    r"\b([1-3]\s?[A-Za-z]+|[A-Za-z]{3,})\s+(\d{1,3})(?::(\d{1,3}))?\b",
                    clean_text
                )
                if ref_match:
                    reference = ref_match.group(0).strip()
            except subprocess.TimeoutExpired:
                ocr_note += " (OCR timed out)"
            except FileNotFoundError:
                ocr_note += " (tesseract not found on PATH)"
            except Exception as e:
                ocr_note += f" (OCR failed: {e})"

        try:
            with open(summary_file, "w") as f:
                f.write(f"Stopped at: {player_time}\n")
                f.write(f"Reference: {reference}\n")
                f.write(f"Screenshot: {latest_shot_name}\n")
                f.write(f"Audio file: {os.path.basename(audio_file)}\n")
                if ocr_note:
                    f.write(f"Note:{ocr_note}\n")
        except Exception as e:
            print(f"[build_summary] Failed to write summary file: {e}")
            return (f"Done. Saved: {os.path.basename(audio_file)}\n"
                    f"WARNING: summary file could not be written ({e})")

        return (f"Done. Saved: {os.path.basename(audio_file)}\n"
                f"Stopped at: {player_time}   Reference: {reference}{ocr_note}\n"
                f"Screenshot: {latest_shot_name}")

    # ---- Cleanup dialog ----

    def open_cleanup_dialog(self):
        win = tk.Toplevel(self.root)
        win.title("Clean Up Screenshots")
        win.geometry("360x220")
        win.resizable(False, False)

        all_pics = glob.glob(os.path.join(PIC_DIR, "*.png"))
        total_size_mb = sum(os.path.getsize(p) for p in all_pics) / (1024 * 1024)

        ttk.Label(win, text=f"{len(all_pics)} screenshots in pic folder\n"
                             f"Using about {total_size_mb:.1f} MB",
                  justify="left").pack(padx=14, pady=10, anchor="w")

        ttk.Label(win, text="Delete screenshots older than:").pack(padx=14, anchor="w")

        age_var = tk.StringVar(value="7")
        age_frame = ttk.Frame(win)
        age_frame.pack(padx=14, pady=6, anchor="w")
        ttk.Entry(age_frame, textvariable=age_var, width=6).pack(side="left")
        ttk.Label(age_frame, text="days").pack(side="left", padx=6)

        def do_cleanup_by_age():
            try:
                days = float(age_var.get())
            except ValueError:
                messagebox.showwarning("Invalid number", "Enter a number of days.")
                return
            cutoff = time.time() - days * 86400
            removed = 0
            for p in glob.glob(os.path.join(PIC_DIR, "*.png")):
                if os.path.getmtime(p) < cutoff:
                    try:
                        os.remove(p)
                        removed += 1
                    except OSError:
                        pass
            messagebox.showinfo("Cleanup complete", f"Removed {removed} screenshot(s).")
            win.destroy()

        def do_cleanup_all():
            if not messagebox.askyesno("Delete all?", "Delete ALL screenshots in the pic folder? This cannot be undone."):
                return
            removed = 0
            for p in glob.glob(os.path.join(PIC_DIR, "*.png")):
                try:
                    os.remove(p)
                    removed += 1
                except OSError:
                    pass
            messagebox.showinfo("Cleanup complete", f"Removed {removed} screenshot(s).")
            win.destroy()

        ttk.Button(win, text="Delete Older Than This", command=do_cleanup_by_age).pack(pady=(10, 4))
        ttk.Button(win, text="Delete ALL Screenshots", command=do_cleanup_all).pack(pady=4)

        def do_cleanup_txt():
            if not messagebox.askyesno("Delete txt files?", "Delete ALL _stopped-at.txt files in the mp3 folder?"):
                return
            removed = 0
            for fpath in glob.glob(os.path.join(MP3_DIR, "*stopped-at.txt")):
                try:
                    os.remove(fpath)
                    removed += 1
                except OSError:
                    pass
            messagebox.showinfo("Cleanup complete", f"Removed {removed} txt file(s).")
            win.destroy()

        ttk.Button(win, text="Delete ALL stopped-at.txt Files", command=do_cleanup_txt).pack(pady=4)
        ttk.Button(win, text="Cancel", command=win.destroy).pack(pady=4)

    def on_close(self):
        if self.recording:
            if not messagebox.askyesno("Recording in progress",
                                        "A recording is still running. Stop it and quit?"):
                return
            self.stop_recording()
        self.root.destroy()


if __name__ == "__main__":
    root = tk.Tk()
    app = RecorderApp(root)
    root.mainloop()
