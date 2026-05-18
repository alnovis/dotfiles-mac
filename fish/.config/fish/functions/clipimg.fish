function clipimg --description "Copy image file to clipboard (PNG/JPEG/TIFF/GIF/BMP)"
    argparse 'h/help' -- $argv; or return 1

    if set -q _flag_help; or test (count $argv) -ne 1
        echo "Usage: clipimg <image-file>"
        echo ""
        echo "Copy an image file into the macOS clipboard so it can be pasted"
        echo "into apps that accept images (Slack, Notes, Preview, etc.)."
        echo ""
        echo "Supported: .png .jpg .jpeg .tif .tiff .gif .bmp"
        return 0
    end

    set -l file $argv[1]
    if not test -f $file
        echo "clipimg: not a file: $file" >&2
        return 1
    end

    set -l abs (realpath -- $file)
    set -l ext (string lower -- (path extension -- $abs))

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
            echo "clipimg: unsupported extension: $ext" >&2
            return 1
    end

    # Escape backslashes and double quotes for the AppleScript string literal
    set -l escaped (string replace -a '\\' '\\\\' -- $abs | string replace -a '"' '\\"')

    osascript -e "set the clipboard to (read (POSIX file \"$escaped\") as $type)"
    or begin
        echo "clipimg: failed to copy $abs" >&2
        return 1
    end

    echo "Copied to clipboard: $abs"
end
