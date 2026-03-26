// @test canPartitionGrid(LC.parseMatrix("[[1,4],[2,3]]")) = true
// @test canPartitionGrid(LC.parseMatrix("[[1,2],[3,4]]")) = false

object Solution:
  def canPartitionGrid(grid: Array[Array[Int]]): Boolean =
    val m = grid.length
    val n = grid(0).length
    val horizon  = Array.tabulate(m)(i => grid(i).map(_.toLong).sum)
    val vertical = Array.tabulate(n)(j => (0 until m).map(i => grid(i)(j).toLong).sum)

    val sum = horizon.sum
    if sum % 2 != 0 then false
    else
      val half = sum / 2
      var count = 0L
      val h = (0 until m - 1).exists { i =>
        count += horizon(i)
        count == half
      }
      count = 0L
      val v = (0 until n - 1).exists { j =>
        count += vertical(j)
        count == half
      }
      h || v
