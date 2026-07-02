#!/usr/bin/env bash
# clip.wl — wl-clipboard (Wayland) backend.
#
# THE LIBRE LESSON: on GNOME/Mutter the Wayland selection path stalls 30-50s
# (the exact bug this whole project came from). So clip.wl rates itself LOW
# (score 20) on GNOME, letting clip.gpaste's fast D-Bus path win instead. On
# non-GNOME Wayland compositors it rates high (80).
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

      @stdout "score N"; then caps when usable. Low (20) on GNOME/Mutter.
      @return 0 always
  '
  [[ -n "$WAYLAND_DISPLAY" && -n "$WLP" && -n "$WLC" ]] || { echo "score 0"; return; }
  local score=80
  [[ "$XDG_CURRENT_DESKTOP" == *GNOME* ]] && score=20   # Mutter selection stalls
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
