function _ai_models_prune --description "Clean up partial downloads and orphaned Ollama blobs"
    set -l blobs_dir ~/.ollama/models/blobs
    set -l manifests_dir ~/.ollama/models/manifests

    if not test -d $blobs_dir
        echo "No Ollama data found"
        return 0
    end

    echo "Scanning $blobs_dir..."

    # Find partial downloads
    set -l partials (find $blobs_dir -name "*-partial" -o -name "*.partial" -o -name "*.tmp" 2>/dev/null)
    set -l partial_count (count $partials)
    set -l partial_size 0

    if test $partial_count -gt 0
        for f in $partials
            set -l fsize (stat -f%z "$f" 2>/dev/null; or echo 0)
            set partial_size (math "$partial_size + $fsize")
        end
    end

    # Find orphaned blobs (not referenced by any manifest)
    set -l referenced_digests
    if test -d $manifests_dir
        set referenced_digests (find $manifests_dir -type f -exec cat {} \; 2>/dev/null | jq -r '.. | .digest? // empty' 2>/dev/null | sort -u)
    end

    set -l orphan_count 0
    set -l orphan_size 0
    set -l orphan_files

    for blob in (find $blobs_dir -type f -not -name "*-partial" -not -name "*.partial" -not -name "*.tmp" 2>/dev/null)
        set -l blob_name (basename $blob)
        # Convert filename format sha256-xxx to sha256:xxx for matching
        set -l blob_digest (string replace -a "-" ":" $blob_name)

        if not contains -- $blob_digest $referenced_digests
            set orphan_count (math $orphan_count + 1)
            set -l fsize (stat -f%z "$blob" 2>/dev/null; or echo 0)
            set orphan_size (math "$orphan_size + $fsize")
            set -a orphan_files $blob
        end
    end

    # Report
    set -l total_size (math "$partial_size + $orphan_size")
    set -l total_gb (math -s2 "$total_size / 1073741824")

    if test $partial_count -eq 0; and test $orphan_count -eq 0
        echo "---"
        set_color green
        echo "Clean — no orphaned data found"
        set_color normal
        return 0
    end

    if test $partial_count -gt 0
        set_color yellow
        echo "Partial downloads: $partial_count"
        set_color normal
        for f in $partials
            echo "  "(basename $f)
        end
    end

    if test $orphan_count -gt 0
        set_color yellow
        echo "Orphaned blobs: $orphan_count"
        set_color normal
    end

    echo ""
    echo "Reclaimable: $total_gb GB"
    echo ""

    read -l -P "Clean up? (y/N) " confirm
    if test "$confirm" != y -a "$confirm" != Y
        echo "Aborted"
        return 1
    end

    # Delete
    set -l deleted 0
    for f in $partials $orphan_files
        rm -f $f
        set deleted (math $deleted + 1)
    end

    echo "---"
    set_color green
    echo "Removed $deleted file(s), freed $total_gb GB"
    set_color normal
end
