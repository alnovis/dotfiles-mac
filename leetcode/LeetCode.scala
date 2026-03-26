import scala.collection.mutable
import scala.collection.mutable.*
import scala.math.*

// --- LeetCode Data Structures ---

class ListNode(var _x: Int = 0):
  var x: Int = _x
  var next: ListNode = null

class TreeNode(var _value: Int = 0):
  var value: Int = _value
  var left: TreeNode = null
  var right: TreeNode = null

// --- Parsers & Formatters ---

object LC:
  // Array parsers
  def parseArray(s: String): Array[Int] =
    val trimmed = s.trim.stripPrefix("[").stripSuffix("]").trim
    if trimmed.isEmpty then Array.empty[Int]
    else trimmed.split(",").map(_.trim.toInt)

  def parseLongArray(s: String): Array[Long] =
    val trimmed = s.trim.stripPrefix("[").stripSuffix("]").trim
    if trimmed.isEmpty then Array.empty[Long]
    else trimmed.split(",").map(_.trim.toLong)

  def parseStringArray(s: String): Array[String] =
    val trimmed = s.trim.stripPrefix("[").stripSuffix("]").trim
    if trimmed.isEmpty then Array.empty[String]
    else trimmed.split(",").map(_.trim.stripPrefix("\"").stripSuffix("\""))

  def parseMatrix(s: String): Array[Array[Int]] =
    val inner = s.trim.stripPrefix("[").stripSuffix("]").trim
    if inner.isEmpty then Array.empty[Array[Int]]
    else
      val rows = ArrayBuffer[Array[Int]]()
      var depth = 0
      var start = 0
      for i <- inner.indices do
        inner(i) match
          case '[' => if depth == 0 then start = i; depth += 1
          case ']' =>
            depth -= 1
            if depth == 0 then rows += parseArray(inner.substring(start, i + 1))
          case _ =>
      rows.toArray

  // ListNode
  def toListNode(arr: Array[Int]): ListNode =
    if arr.isEmpty then null
    else
      val head = ListNode(arr(0))
      var curr = head
      for i <- 1 until arr.length do
        curr.next = ListNode(arr(i))
        curr = curr.next
      head

  def fromListNode(head: ListNode): String =
    val buf = ArrayBuffer[Int]()
    var curr = head
    while curr != null do
      buf += curr.x
      curr = curr.next
    buf.mkString("[", ",", "]")

  // TreeNode (level-order, LeetCode format)
  def toTreeNode(s: String): TreeNode =
    val trimmed = s.trim.stripPrefix("[").stripSuffix("]").trim
    if trimmed.isEmpty then return null
    val parts = trimmed.split(",").map(_.trim)
    if parts.isEmpty || parts(0) == "null" then return null
    val root = TreeNode(parts(0).toInt)
    val queue = mutable.Queue[TreeNode](root)
    var i = 1
    while i < parts.length && queue.nonEmpty do
      val node = queue.dequeue()
      if i < parts.length && parts(i) != "null" then
        node.left = TreeNode(parts(i).toInt)
        queue.enqueue(node.left)
      i += 1
      if i < parts.length && parts(i) != "null" then
        node.right = TreeNode(parts(i).toInt)
        queue.enqueue(node.right)
      i += 1
    root

  def fromTreeNode(root: TreeNode): String =
    if root == null then return "[]"
    val result = ArrayBuffer[String]()
    val queue = mutable.Queue[TreeNode](root)
    while queue.nonEmpty do
      val node = queue.dequeue()
      if node == null then result += "null"
      else
        result += node.value.toString
        queue.enqueue(node.left)
        queue.enqueue(node.right)
    // Trim trailing nulls
    while result.nonEmpty && result.last == "null" do result.dropRightInPlace(1)
    result.mkString("[", ",", "]")

  // Result formatting
  def fmt(v: Any): String = v match
    case arr: Array[Array[Int]] => arr.map(_.mkString("[", ",", "]")).mkString("[", ",", "]")
    case arr: Array[Int]        => arr.mkString("[", ",", "]")
    case arr: Array[Long]       => arr.mkString("[", ",", "]")
    case arr: Array[String]     => arr.map(s => s"\"$s\"").mkString("[", ",", "]")
    case list: List[_]          => list.mkString("[", ",", "]")
    case ln: ListNode           => fromListNode(ln)
    case tn: TreeNode           => fromTreeNode(tn)
    case other                  => other.toString
