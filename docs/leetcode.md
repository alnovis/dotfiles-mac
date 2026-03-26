# LeetCode Runner

Offline tool for running LeetCode solutions with test cases. Supports Scala 3 and Rust.

## Quick Start

```fish
# From terminal
lc-run solution.scala
lc-run solution.rs

# From Neovim (open solution file, then)
Space lr
```

## Test Format

Add `@test` comments at the top of the solution file:

**Scala:**
```scala
// @test methodName(args) = expected

// Arrays
// @test twoSum(LC.parseArray("[2,7,11,15]"), 9) = LC.parseArray("[0,1]")

// Matrices
// @test canPartitionGrid(LC.parseMatrix("[[1,4],[2,3]]")) = true

// Strings
// @test isValid("()[]{}") = true

// LinkedList
// @test reverseList(LC.toListNode(Array(1,2,3,4,5))) = LC.toListNode(Array(5,4,3,2,1))

// BinaryTree
// @test maxDepth(LC.toTreeNode("[3,9,20,null,null,15,7]")) = 3
```

**Rust:**
```rust
// @test method_name(args) = expected

// Arrays
// @test two_sum(vec![2,7,11,15], 9) = vec![0,1]

// Matrices
// @test can_partition_grid(vec![vec![1,4],vec![2,3]]) = true

// Strings
// @test is_valid("()[]{}".to_string()) = true
```

## Solution Format

**Scala** — standard `object Solution`:
```scala
// @test canPartitionGrid(LC.parseMatrix("[[1,4],[2,3]]")) = true
// @test canPartitionGrid(LC.parseMatrix("[[1,2],[3,4]]")) = false

object Solution:
  def canPartitionGrid(grid: Array[Array[Int]]): Boolean =
    // your solution here
```

**Rust** — standard `impl Solution`:
```rust
// @test max_product_path(vec![vec![1,-2,1],vec![1,-2,1],vec![3,-4,1]]) = 8
// @test max_product_path(vec![vec![-1,-2,-3],vec![-2,-3,-3],vec![-3,-3,-2]]) = -1

impl Solution {
    pub fn max_product_path(grid: Vec<Vec<i32>>) -> i32 {
        // your solution here
    }
}
```

## LC Helper Library (Scala)

`LeetCode.scala` provides data structures and parsers matching LeetCode environment.

### Data Structures

```scala
class ListNode(var _x: Int = 0)     // singly-linked list
class TreeNode(var _value: Int = 0) // binary tree
```

### Parsers

| Function | Input | Output |
|----------|-------|--------|
| `LC.parseArray("[1,2,3]")` | LeetCode string | `Array[Int]` |
| `LC.parseLongArray("[1,2,3]")` | LeetCode string | `Array[Long]` |
| `LC.parseStringArray("[\"a\",\"b\"]")` | LeetCode string | `Array[String]` |
| `LC.parseMatrix("[[1,2],[3,4]]")` | LeetCode string | `Array[Array[Int]]` |
| `LC.toListNode(Array(1,2,3))` | Array | `ListNode` |
| `LC.toTreeNode("[1,2,3,null,4]")` | LeetCode string | `TreeNode` |

### Formatters

| Function | Input | Output |
|----------|-------|--------|
| `LC.fromListNode(head)` | `ListNode` | `"[1,2,3]"` |
| `LC.fromTreeNode(root)` | `TreeNode` | `"[1,2,3,null,4]"` |
| `LC.fmt(value)` | Any result | String for comparison |

### Available Imports

Automatically included (matches LeetCode Scala 3 environment):

```scala
import scala.collection.mutable
import scala.collection.mutable.*
import scala.math.*
```

## Rust Runner

For Rust, `lc-run` auto-generates:
- `struct Solution;`
- `ListNode` and `TreeNode` definitions
- `use std::collections::*;`
- `use std::rc::Rc;` and `use std::cell::RefCell;`

No separate library file needed.

## Output

```
Test 1: ✓  true
Test 2: ✓  false
Test 3: ✗  got 5, expected 3
Debug: some println output
── 2/3 passed ──
```

## Neovim Keymaps

| Key | Cyrillic | Description |
|-----|----------|-------------|
| `<leader>lr` | `<leader>дк` | Run tests for current file |

## File Organization

```
leetcode/
  LeetCode.scala              # shared library (Scala)
  3546_equal_sum_grid_partition.scala
  1594_max_non_negative_product.scala
  1594_max_non_negative_product.rs
  ...
```

## Tips

- **No `main` needed** — `lc-run` generates it from `@test` comments
- **Debug with `println`** — output appears in the test runner
- **No build.sbt needed** — uses `scala` CLI directly
- **Multiple solutions** — use different filenames (e.g., `3546_v1.scala`, `3546_v2.scala`)
- **No Metals in leetcode dir** — delete `.bsp/`, `.metals/`, `.scala-build/` if auto-created
