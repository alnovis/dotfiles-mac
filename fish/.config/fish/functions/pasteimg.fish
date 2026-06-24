function pasteimg --description "Save clipboard image to a file (PNG/JPEG/TIFF/GIF/BMP)"
    argparse 'h/help' -- $argv; or return 1

    if set -q _flag_help; or test (count $argv) -ne 1
        echo "Usage: pasteimg <output-file>"
        echo ""
        echo "Write the image currently on the macOS clipboard to a file."
        echo "The output format is chosen from the file extension, converting"
        echo "the clipboard image if needed (e.g. a copied PNG saved as .jpg)."
        echo ""
        echo "Supported: .png .jpg .jpeg .tif .tiff .gif .bmp"
        return 0
    end

    set -l file $argv[1]
    set -l ext (string lower -- (path extension -- $file))

    set -l type
    switch $ext
        case .png
            set type '«class PNGf»'
        case .jpg .jpeg
            set type 'JPEG picture'
        case .tif .tiff
            set type 'TIFF picture'
        case .gif
            set type 'GIF picture'
        case .bmp
            set type '«class BMP »'
        case '*'
            echo "pasteimg: unsupported extension: $ext (use .png .jpg .tif .gif .bmp)" >&2
            return 1
    end

    # Resolve to an absolute path; the parent directory must already exist.
    set -l dir (path dirname -- $file)
    set -l absdir (realpath -- $dir 2>/dev/null)
    if test -z "$absdir"
        echo "pasteimg: directory does not exist: $dir" >&2
        return 1
    end
    set -l abs "$absdir/"(path basename -- $file)

    # Escape backslashes and double quotes for the AppleScript string literal
    set -l escaped (string replace -a '\\' '\\\\' -- $abs | string replace -a '"' '\\"')

    # Read the clipboard first so a non-image clipboard fails before any file
    # is created; then truncate and write the bytes.
    osascript \
        -e "set imgData to (the clipboard as $type)" \
        -e "set f to (open for access POSIX file \"$escaped\" with write permission)" \
        -e "set eof f to 0" \
        -e "write imgData to f" \
        -e "close access f" 2>/dev/null
    or begin
        echo "pasteimg: no image on clipboard (or failed to write $abs)" >&2
        return 1
    end

    echo "Saved clipboard image: $abs"
end
