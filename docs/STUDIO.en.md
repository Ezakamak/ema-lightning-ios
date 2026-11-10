# EMA Studio

Create real offline EMA audio from up to 1,000 Turkish characters. Finished
synthesis is saved as WAV with its original text in local history before
preview playback. Browse/search, play/pause/seek, rename, reuse text or delete
recordings. Apple's explicitly selected voice is a preview, not an EMA recording.

Export MP3 (128 kbps mono) or MP4 (H.264/AAC, portrait 720×1280, 12 fps).
The MP4 contains the logo and timed phrase cards. Phrase timing is estimated
from text lengths and audio duration: EMA provides no word alignment timestamps.
Text is burned into the video. All encoding is offline. The system share sheet
provides installed destinations; WhatsApp/Instagram compatibility, upload limits
and transcoding still depend on those apps. Users choose where to send a file.

Exports can be cancelled; moving the app into the background cancels an active
export. Partial files are not shared. Temporary exports older than 24 hours are
cleaned on subsequent launch. Local text/audio history is user content and is
not sent to the developer; OS backups follow system settings. Uninstalling the
app removes its local history. Settings offers a confirmed delete-all action.

Developer Mode defaults off. Enable it in Settings for all 20 stages, timing,
detailed errors and copy/share diagnostics. Diagnostic reports redact input,
unlike a video that intentionally contains the user's text.

Application source stays Apache-2.0. The separate, replaceable lamejs encoder
is LGPL-3.0; its full source archive and replacement instructions are bundled
and accessible through Settings → Licenses. See DEPENDENCIES.md.
