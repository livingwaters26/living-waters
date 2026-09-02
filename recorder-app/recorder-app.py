#!/usr/bin/env python3
"""
Recorder App — simple GUI wrapper around the record-study.sh workflow.

Three fields (Title / Field 2 / Field 3) combine into the output filename.
Start button begins recording system audio + a rolling screenshot buffer
in the background; Stop runs OCR on the latest screenshot and writes a
summary. A Cleanup button lets you clear out old screenshots so the pic
folder doesn't grow unbounded.

Requires: ffmpeg, imagemagick (import), tesseract-ocr — all already
installed from the terminal setup earlier.
"""

import os
import re
import glob
import signal
import subprocess
import threading
import time
import tkinter as tk
from tkinter import ttk, messagebox

# ---- Configuration (matches record-study.sh) ----
MP3_DIR = "/srv/share/bigstorage/mp3"
PIC_DIR = "/srv/share/bigstorage/pic"
SOURCE = "alsa_output.pci-0000_00_1f.3.analog-stereo.monitor"
SCREENSHOT_INTERVAL = 20  # seconds
KEEP_SCREENSHOTS = 9      # ~3 minutes of rolling buffer per session


NOISE_SNIPPETS = [
    "field 2", "field 3", "title", "auto-stop", "minutes (blank",
    "start recording", "clean up old", "stopped-at", "screenshot:",
    "audio file:", "recorder", "e.g. chapter", "e.g. verse",
    "idle.", "done. saved", "leno330", "willm@",
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
        root.geometry("420x560")
        root.resizable(False, False)
        root.attributes("-topmost", True)

        self.recording = False
        self.ffmpeg_proc = None
        self.shot_thread = None
        self.stop_event = threading.Event()
        self.start_time = None
        self.basename = None
        self.timestamp = None
        self.timer_job = None
        self.max_duration_secs = None

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

        # Big elapsed-time readout
        self.elapsed_var = tk.StringVar(value="00:00")
        self.elapsed_label = ttk.Label(root, textvariable=self.elapsed_var, font=("", 28, "bold"), anchor="center")
        self.elapsed_label.pack(pady=(4, 0))

        self.progress = ttk.Progressbar(root, orient="horizontal", length=380, mode="determinate", maximum=100)
        self.progress.pack(padx=10, pady=(6, 2))

        self.remaining_var = tk.StringVar(value="")
        self.remaining_label = ttk.Label(root, textvariable=self.remaining_var, anchor="center")
        self.remaining_label.pack(pady=(0, 6))

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
                ["ffmpeg", "-nostdin", "-y", "-f", "pulse", "-i", SOURCE,
                 "-ac", "2", "-ab", "192k", audio_file],
                stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL
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
        self.elapsed_var.set("00:00")
        self.remaining_var.set("")
        self.progress["value"] = 0
        self.start_btn.config(state="disabled")
        self.stop_btn.config(state="normal")
        self.title_entry.config(state="disabled")
        self.field2_entry.config(state="disabled")
        self.field3_entry.config(state="disabled")

        if self.max_duration_secs:
            mins = self.max_duration_secs / 60
            self.status_var.set(f"Recording will auto-stop after {mins:g} minutes.")

        self.tick()

    def screenshot_loop(self):
        while not self.stop_event.is_set():
            ts = time.strftime("%H%M%S")
            shot_path = os.path.join(PIC_DIR, f"{self.basename}_{self.timestamp}_{ts}.png")
            try:
                subprocess.run(["import", "-window", "root", shot_path],
                                stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            except FileNotFoundError:
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

        limit_note = ""
        if self.max_duration_secs:
            pct = min(100, (elapsed_secs / self.max_duration_secs) * 100)
            self.progress["value"] = pct
            remaining = int(self.max_duration_secs - elapsed_secs)
            rmins, rsecs = divmod(max(remaining, 0), 60)
            self.remaining_var.set(f"Auto-stop in {rmins:02d}:{rsecs:02d}")
            limit_note = f"  (auto-stop in {rmins:02d}:{rsecs:02d})"

        self.status_var.set(f"Recording \"{self.basename}\"...  Elapsed: {mins:02d}:{secs:02d}{limit_note}\n"
                             f"You can close this window's view and walk away — it keeps running.")
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

        if self.ffmpeg_proc:
            try:
                self.ffmpeg_proc.send_signal(signal.SIGTERM)
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

        summary = self.build_summary()
        self.status_var.set("Idle. Fill in the fields above and click Start.")
        self.summary_var.set(summary)

    def build_summary(self):
        pattern = os.path.join(PIC_DIR, f"{self.basename}_{self.timestamp}_*.png")
        shots = sorted(glob.glob(pattern), key=os.path.getmtime, reverse=True)
        audio_file = self.audio_path()
        summary_file = os.path.join(MP3_DIR, f"{self.basename}_{self.timestamp}_stopped-at.txt")

        player_time = "unknown"
        reference = "not detected"
        latest_shot_name = "none"

        if shots:
            latest_shot = shots[0]
            latest_shot_name = os.path.basename(latest_shot)
            try:
                ocr_text = subprocess.run(
                    ["tesseract", latest_shot, "stdout", "--psm", "11"],
                    stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True
                ).stdout
            except FileNotFoundError:
                ocr_text = ""

            clean_text = strip_noise(ocr_text)

            time_match = re.search(r"\b[0-9]{1,2}:[0-9]{2}\b", clean_text)
            if time_match:
                player_time = time_match.group(0)

            ref_match = re.search(r"[1-3]?\s?[A-Z][a-z]+ [0-9]+(:[0-9]+)?", clean_text)
            if ref_match:
                reference = ref_match.group(0)
        with open(summary_file, "w") as f:
            f.write(f"Stopped at: {player_time}\n")
            f.write(f"Reference: {reference}\n")
            f.write(f"Screenshot: {latest_shot_name}\n")
            f.write(f"Audio file: {os.path.basename(audio_file)}\n")

        return (f"Done. Saved: {os.path.basename(audio_file)}\n"
                f"Stopped at: {player_time}   Reference: {reference}\n"
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
