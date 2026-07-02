#!/usr/bin/env bash
# clip.wl — wl-clipboard (Wayland) backend.
#
# THE LIBRE LESSON (historical): on GNOME/Mutter the Wayland selection path can
# stall 30-50s (the bug this whole project came from), which used to make
# clip.wl rate itself LOW (score 20) on GNOME so clip.gpaste won.
#
# DECISION (Task B): wl-clipboard is now the CHOSEN PRIMARY backend here — it is
# the only one that offers rich/image formatting, and the dispatcher wraps every
# call in a timeout with fallback (see clip.sh), so an occasional Mutter stall
# degrades gracefully to gpaste instead of hanging. The old GNOME penalty is
# therefore DROPPED: clip.wl rates HIGH (70) even on GNOME, out-scoring gpaste
# (50), while gpaste stays running as a lower-priority plain-only fallback.
#
# We must reach the REAL wl-paste/wl-copy binaries, NOT our own wl-* shims
# (which route back through the front-ends and would recurse). clip::real_binary
# resolves the system binary and skips text-script shims (--need-binary).
#
# Sourced directly (not via include-source): the dispatcher lib does not resolve
# through include-source in this worktree (BASH_LIB_PATH points at the main repo).
source "$(dirname "$(readlink -f "$0")")/../lib/clip.sh"

WLP="$(clip::real_binary wl-paste --need-binary)"
WLC="$(clip::real_binary wl-copy --need-binary)"

probe() {
  : 'Self-rate this backend.

      @stdout "score N"; then caps when usable. High (70+) — chosen primary.
      @return 0 always
  '
  [[ -n "$WAYLAND_DISPLAY" && -n "$WLP" && -n "$WLC" ]] || { echo "score 0"; return; }
  # 80 off-GNOME, 70 on GNOME. The old Mutter penalty (was 20) is dropped: wl is
  # the chosen primary (only rich/image backend) and the dispatcher's timeout +
  # fallback covers stalls, so wl must still out-score the gpaste fallback (50).
  local score=80
  [[ "$XDG_CURRENT_DESKTOP" == *GNOME* ]] && score=70
  echo "score $score"
  echo "caps get:plain set:plain get:rich set:rich get:image set:image"
}

main() {
  : 'Provider entrypoint.

      @arg $1 subcommand (probe|get|set)
      @arg $2 type (plain|rich|image)
  '
  case "$1" in
    probe) probe ;;
    get) case "$2" in
           plain) "$WLP" --no-newline ;;
           rich)  "$WLP" -t text/html ;;
           image) "$WLP" -t image/png ;;
         esac ;;
    set) case "$2" in
           plain) "$WLC" ;;
           rich)  "$WLC" -t text/html ;;
           image) "$WLC" -t image/png ;;
         esac ;;
  esac
}

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && main "$@"
