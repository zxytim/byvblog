class List
  class ListNode
    constructor: (@prev = null, @next = null, @data = null) ->

  constructor: () ->
    @head = new ListNode()
    @tail = new ListNode()
    @head.next = @tail
    @tail.prev = @head

  makeConnection: (a, b, c, d) ->
    (a.next = d).prev = a
    (c.next = b).prev = c

  connectNode: (n0, n1) ->
    n0.next = n1
    n1.prev = n0


  swapNode: (n0, n1) ->
    return if n0 is n1
    @makeConnection n0.prev, n0, n1.prev, n1
    @makeConnection n0, n0.next, n1, n1.next

  removeNode: (node) ->
    n0 = node.prev
    n1 = node.next
    delete n0.next
    delete n1.prev
    n0.next = n1
    n1.prev = n0
    

  append: (data) ->
    node = new ListNode(@tail.prev, @tail, data)
    @tail.prev.next = node
    @tail.prev = node

  asArray: () ->
    ret = []
    cur = @head.next
    while cur isnt @tail
      ret.push cur.data
      cur = cur.next
    ret
