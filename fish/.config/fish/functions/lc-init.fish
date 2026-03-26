function lc-init --description "Generate Cargo project from .rs leetcode files for rust-analyzer"
    if contains -- --help $argv; or contains -- -h $argv
        echo "Usage: lc-init [DIR]"
        echo ""
        echo "Scan .rs files and generate Cargo.toml + wrapper sources"
        echo "for rust-analyzer support. User files are not modified."
        echo "Defaults to current directory."
        return 0
    end

    set -l dir (test (count $argv) -ge 1; and echo $argv[1]; or pwd)

    set -l rs_files (find $dir -maxdepth 1 -name "*.rs" -not -path "*/src/*" | sort)
    if test (count $rs_files) -eq 0
        echo "No .rs files found in $dir"
        return 1
    end

    # Create src/ for wrappers
    mkdir -p "$dir/src"

    set -l cargo "$dir/Cargo.toml"
    echo '[package]' >$cargo
    echo 'name = "leetcode"' >>$cargo
    echo 'version = "0.0.0"' >>$cargo
    echo 'edition = "2021"' >>$cargo
    echo '' >>$cargo

    set -l count 0
    for f in $rs_files
        set -l basename_rs (basename $f)
        set -l name (basename $f .rs | string replace -a '-' '_')
        set -l wrapper "$dir/src/$basename_rs"

        # Generate wrapper that includes the original file
        echo "#![allow(unused_imports, dead_code)]" >$wrapper
        echo "use std::collections::*;" >>$wrapper
        echo "use std::rc::Rc;" >>$wrapper
        echo "use std::cell::RefCell;" >>$wrapper
        echo "" >>$wrapper
        echo "#[derive(Debug, Clone, PartialEq, Eq)]" >>$wrapper
        echo "pub struct ListNode { pub val: i32, pub next: Option<Box<ListNode>> }" >>$wrapper
        echo "impl ListNode { fn new(val: i32) -> Self { ListNode { val, next: None } } }" >>$wrapper
        echo "" >>$wrapper
        echo "#[derive(Debug, Clone, PartialEq, Eq)]" >>$wrapper
        echo "pub struct TreeNode { pub val: i32, pub left: Option<Rc<RefCell<TreeNode>>>, pub right: Option<Rc<RefCell<TreeNode>>> }" >>$wrapper
        echo "" >>$wrapper
        echo "struct Solution;" >>$wrapper
        echo "" >>$wrapper
        echo "include!(\"../$basename_rs\");" >>$wrapper
        echo "" >>$wrapper
        echo "fn main() {}" >>$wrapper

        echo "[[bin]]" >>$cargo
        echo "name = \"$name\"" >>$cargo
        echo "path = \"src/$basename_rs\"" >>$cargo
        echo "" >>$cargo

        set count (math $count + 1)
    end

    echo "---"
    set_color green
    echo "Generated Cargo.toml + $count wrapper(s) in src/"
    set_color normal
    echo "Run 'cargo check' or restart nvim for rust-analyzer"
end
