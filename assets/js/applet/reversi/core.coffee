#= require set
root = exports ? this
if require?
  $ = require 'jquery'
  Set = (require './set').Set
else if jQuery?
  $ = jQuery
  
assert = (exp, msg) ->
  return if exp is true
  throw new Error "assertion failed: #{msg}"

_deepCopy = (val) ->
  return val if typeof val is 'undefined' or val is null
  if val.constructor is Object
    return $.extend(true, {}, val)
  if val.constructor is Array
    return $.extend(true, [], val)
  return val

hashDeepMerge = (h0, h1) ->
  ret = $.extend(true, {}, h0, {})
  for key, val of h1
    if ret.hasOwnProperty(key)
      v0 = ret[key]
      if v0.constructor is Object and (typeof val isnt 'undefined' and val.constructor is Object)
          ret[key] = hashDeepMerge v0, val
      else ret[key] = _deepCopy val
    else
      ret[key] = _deepCopy val
  ret

deepCopy = (val) ->
  hashDeepMerge {}, val

Array.prototype.last = () ->
  this[this.length - 1]
Array.prototype.first = () ->
  this[0]

# used in where efficiency is of no importance
range = () ->
  return [] if arguments.length == 0
  return [0..arguments[0] - 1] if arguments.length == 1
  return [arguments[0]..arguments[1] - 1]

# defines
[empty, white, black] = [0, 1, 2]
chessSet = [white, black]

flipTurn = (turn) ->
  if turn is black then white else black
infVal = 1000000000

class ReversiBoard extends Array
  constructor: (n) ->
    @n = n
    @nblack = 2
    @nwhite = 2
    this[i] = [] for i in range(n)
    this[i][j] = empty for i in range(n) for j in range(n)
    this[n / 2 - 1][n / 2 - 1] = this[n / 2][n / 2] = black
    this[n / 2 - 1][n / 2] = this[n / 2][n / 2 - 1] = white

    @dirs = []
    for i in [-1..1]
      for j in [-1..1]
        if i isnt 0 or j isnt 0
          @dirs.push [i, j]

    @enableHistory = false
    # schema of BoardChange:
    #   for new chess:
    #     [color, x, y]
    #   for flip
    #     [0, x, y]
    #
    # schema of History:
    # [
    #   [BoardChange, BoardChange, ...],
    #   [BoardChange, BoardChange, ...],
    #   ...
    # ]
    @history = []


  rollback: () ->
    return if @history.length is 0
    history = @history.pop()
    for [type, x, y] in history
      this[x][y] = type
    return

  # assume checked
  putChess: (x, y, type) ->
    #return false if x < 0 or x >= @n or y < 0 or y >= @n
    #return false if this[x][y] not empty
    if @enableHistory
      history = []
      history.push [0, x, y]

    this[x][y] = type
    for [dx, dy] in @dirs
      [tx, ty] = [x + dx, y + dy]
      continue if not @inBoard tx, ty
      continue if this[tx][ty] is empty
      continue if this[tx][ty] is type
      tx += dx; ty += dy
      other = flipTurn type
      while (@inBoard tx, ty) and this[tx][ty] is other
        tx += dx; ty += dy

      if (@inBoard tx, ty) and this[tx][ty] is type
        # this way is valid
        tx -= dx; ty -= dy
        while tx isnt x or ty isnt y
          history.push [other, tx, ty] if @enableHistory
          this[tx][ty] = type
          tx -= dx; ty -= dy

    if @enableHistory
      @history.push history

  inBoard: (x, y) ->
    return x >= 0 && x < @n && y >= 0 && y < @n

  flipTurn: (turn) ->
    if turn is black then white else black

  # more efficient check
  canPutChess: (x, y, type) ->
    return false if not @inBoard x, y
    return false if this[x][y] isnt empty
    for [dx, dy] in @dirs
      [tx, ty] = [x + dx, y + dy]
      continue if not @inBoard tx, ty
      continue if this[tx][ty] is empty
      continue if this[tx][ty] is type
      tx += dx; ty += dy
      other = flipTurn type
      while (@inBoard tx, ty) and this[tx][ty] is other
        tx += dx; ty += dy
      return true if (@inBoard tx, ty) and this[tx][ty] is type
    return false

  missTurn: (turn) ->
    for i in [0..@n-1] by 1
      for j in [0..@n-1] by 1
        return false if @canPutChess i, j, turn
    return true

  gameEnds: () ->
    (@missTurn black) and (@missTurn white)
  getParams: (turn) ->
    nMyChess = nOpChess = 0
    for i in [0..@n-1] by 1
      for j in [0..@n-1] by 1
        c = this[i][j]
        continue if c is empty
        if c is turn
          nMyChess += 1
        else nOpChess += 1
    return [nMyChess, nOpChess]

  toString: () ->
    str = ""
    for y in range @n
      for x in range @n
        str += "#{this[x][y]}"
      str += "\n"
    str

  fromString: (str) ->
    lines = str.split('\n')
    @n = 0
    for line in lines
      continue if line.length <= 2
      this[@n] = []
      for c in line
        continue if c is '\n'
        this[@n].push c.charCodeAt(0) - '0'.charCodeAt(0)
      @n += 1

  print: () ->
    console.log @toString()

  hint: (type) ->
    ret = []
    for x in range @n
      for y in range @n
        if @canPutChess x, y, type
          ret.push [x, y]
    ret

# this is the core AI of reversi
# {
# TODO:
#   for SEARCH:
#     active grid maintenance
#     hashTable
#     killTable?
#     zero window
#     weighted mobility
#     forward prunning
#   for EVALUATE:
#     eval(board, player) = EC * Edge Advantage +
#       MC * Mobility Advantage +
#       SC * Occupied Square Advantage
#
#     Edge Advantage:
#       normalized in [-1000, 1000]
#       evaluate 3^(8 + 4) = 531441 states + probabilistic minimax search
#
#     Internal Tables (for MA and OSA):
#       Weighted Mobility: estimate by internal table
#         inferior:
#           place in A fliped X
#           more discs fliped
#         superior:
#           central
#       Potential mobility:
#         frontier discs, calculated exactly
#     
class ReversiSearchState
  constructor: (board, turn) ->

    @history = []

    @board = deepCopy board
    @turn = turn
    @depth = 0
    @step = 0
    @alpha = -infVal
    @beta = infVal
    @lastPos = null
    [@nMyChess, @nOpChess] = @board.getParams @turn
    @nMissedTurn = 0

  missTurn: () ->
    @history.push [0, @alpha, @beta, @turn, @nMyChess, @nOpChess, @nMissedTurn, @lastPos]
    @nMissedTurn += 1
    @turn = flipTurn @turn
    @lastPos = null
    [@alpha, @beta] = [-@beta, -@alpha]
    [@nMyChess, @nOpChess] = [@nOpChess, @nMyChess]

  putChess: (x, y) ->
    @history.push [1, @alpha, @beta, @turn, @nMyChess, @nOpChess, @nMissedTurn, @lastPos]
    @board.putChess x, y, @turn
    @turn = flipTurn @turn
    @step += 1
    @depth += 1
    @nMissedTurn = 0
    @lastPos = [x, y]
    [@alpha, @beta] = [-@beta, -@alpha]
    [@nMyChess, @nOpChess] = @board.getParams @turn

  rollback: () ->
    [type, @alpha, @beta, @turn, @nMyChess, @nOpChess, @nMissedTurn, @lastPos] = @history.pop()
    if type
      @step -= 1
      @depth -= 1
      @board.rollback()

  shouldEvaluate: (searchDepthMax) ->
    ret = @depth is searchDepthMax or @nMissedTurn is 2 or @nMyChess is 0 or @nOpChess is 0 or @nMyChess + @nOpChess is @board.n * @board.n
    #if ret
    #  console.log @depth, @nMissedTurn, @nMyChess, @nOpChess
    ret

  toString: () ->
    ret = @board.toString()
    ret += "turn: #{@turn}\n"
    ret += "depth: #{@depth}\n"
    ret += "step: #{@step}\n"
    ret += "alpha,beta: #{@alpha},#{@beta}\n"
    ret += "nMyChess,nOpChess: #{@nMyChess},#{@nOpChess}\n"
    ret += "nMissedTurn: #{@nMissedTurn}"


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

  last: () ->
    @tail.prev

class KillerTable
  constructor: (board) ->
    @n = board.n

    newTable = (func = () -> null) ->
      ret = []
      for i in [0..board.n - 1] by 1
        ret.push []
        for j in [0..board.n - 1] by 1
          ret[i][j] = func(i, j)
      ret
    @squareList = newTable () -> new List()
    @squareListMap = newTable () -> newTable()


    for x in [0..@n - 1] by 1
      for y in [0..@n - 1] by 1
        if board[x][y] is empty
          for i in [0..@n - 1] by 1
            for j in [0..@n - 1] by 1
              if board[i][j] is empty and (i isnt x or j isnt y)
                @squareList[x][y].append i * @n + j
                @squareListMap[x][y][i][j] = @squareList[x][y].last()

    # TODO
    update: (x, y, board) ->
      list = @squareList[x][y]
      map = @squareListMap[x][y]

class Reversi
  constructor: (n) ->
    @n = n

    # settings are exposed to class variable
    # before search
    @settings = {}
    @settingsDefault =
      searchDepthMax: 8
      searchTimeMax: 3 # in second
      enableZeroWindow: false

    @killerTable = null
    @nState = 0
    @depthMax = 0


    initTable = (val) ->
      ret = []
      for i in [0..n-1] by 1
        ret.push []
        for j in [0..n-1] by 1
          ret[i][j] = val
      ret

    # misc tables

    # corner related
    @tblIsCorner = initTable false
    @tblIsCorner[0][0] = @tblIsCorner[0][@n - 1] = @tblIsCorner[@n - 1][0] = @tblIsCorner[@n - 1][@n - 1] = true
    
    @tblCorners = []
    for i in range @n
      for j in range @n
        if @tblIsCorner[i][j]
          @tblCorners.push [i, j]

    # X square related
    @tblIsXSquare = initTable false
    @tblIsXSquare[1][1] = @tblIsXSquare[1][@n - 2] = @tblIsXSquare[@n - 2][1] = @tblIsXSquare[@n - 2][@n - 2] = true

    @tblXSquareAdjacentCorner = initTable null
    @tblXSquareAdjacentCorner[1][1] = [0, 0]
    @tblXSquareAdjacentCorner[1][@n - 2] = [0, @n - 1]
    @tblXSquareAdjacentCorner[@n - 2][1] = [@n - 1, 0]
    @tblXSquareAdjacentCorner[@n - 2][@n - 2] = [@n - 1, @n - 1]

    @tblXSquareAdjacentCSquares = initTable null
    @tblXSquareAdjacentCSquares[1][1] = [[0, 1], [1, 0]]
    @tblXSquareAdjacentCSquares[1][@n - 2] = [[1, @n - 1],[0, @n - 2]]
    @tblXSquareAdjacentCSquares[@n - 2][1] = [[@n - 1, 1], [@n - 2, 0]]
    @tblXSquareAdjacentCSquares[@n - 2][@n - 2] = [[@n - 1, @n - 2], [@n - 2, @n - 1]]

    # C square related
    @tblIsCSquare = initTable false
    @tblCSquareAdjacentASquare = initTable null
    @tblCSquareAdjacentBSquare = initTable null
    @tblCSquareAdjacentCorner = initTable null
    @tblCSquares = []
    for [cx, cy] in @tblCorners
      dirs = [[1, 0], [-1, 0], [0, 1], [0, -1]]
      for [dx, dy] in dirs
        tx = cx + dx; ty = cy + dy
        if @inBoard tx, ty
          @tblIsCSquare[tx][ty] = true
          @tblCSquares.push [tx, ty]
          @tblCSquareAdjacentASquare[tx][ty] = [tx + dx, ty + dy]
          @tblCSquareAdjacentBSquare[tx][ty] = [tx + dx * 2, ty + dy * 2]
          @tblCSquareAdjacentCorner[tx][ty] = [cx, cy]

  init: () ->
    #TODO

  inBoard: (x, y) ->
    return x >= 0 && x < @n && y >= 0 && y < @n

  evaluateState: (state) ->
    return -infVal if state.nMyChess is 0
    return infVal if state.nOpChess is 0

    ret = 0
    for i in [0..@n-1] by 1
      for j in [0..@n-1] by 1
        c = state.board[i][j]
        continue if c is empty
        ret += (if c is state.turn then 1 else -1)
    return ret


  forwardPruneXSquare: (state, x, y) ->
    return false if not @tblIsXSquare[x][y]
    return false if state.nOpChess + state.nMyChess >= 35
  
    # if the adjacent corner is occupied, do not prune
    [cx, cy] = @tblXSquareAdjacentCorner[x][y]
    return false if state.board[cx][cy] isnt empty

    # if both adjacent C-squares are occupied, always prune
    [[x0, y0], [x1, y1]] = @tblXSquareAdjacentCSquares[x][y]
    return true if state.board[x0][x1] isnt empty and state.board[x1][y1] isnt empty
    return state.nOpChess + state.nMyChess < 25

  forwardPruneCSquare: (state, x, y) ->
    return false if not @tblIsCSquare[x][y]
    #return false if state.depth > 1

    [corX, corY] = @tblCSquareAdjacentCorner[x][y]
    [aX, aY] = @tblCSquareAdjacentASquare[x][y]
    [bX, bY] = @tblCSquareAdjacentBSquare[x][y]
    return false if not (state.board[corX][corY] is empty and state.board[aX][aY] is empty)
    return false if state.board[bX][bY] isnt empty
    return state.nMissedTurn + state.nOpChess < 28

  # XXX: may cause missTurn fault, not fixed
  forwardPrune: (state, x, y) ->
    return true if @forwardPruneXSquare state, x, y
    return true if @forwardPruneCSquare state, x, y
    return false

  # common variable shared:
  #   @hashTable
  #   @killerTable
  doSearch: (state) ->
    @nState += 1
    @depthMax = state.depth if state.depth > @depthMax
    if state.shouldEvaluate(@searchDepthMax)
      return @evaluateState state

    epsilon = 0.001
    forwardPrunedSquares = []
    other = flipTurn turn
    turn = state.turn
    fliped = false
    for x in [0..@n-1] by 1
      for y in [0..@n-1] by 1
        if @forwardPrune state, x, y
          forwardPrunedSquares.push [x, y]
          continue
        if state.board.canPutChess x, y, turn
          fliped = true

          if @enableZeroWindow
            alpha = state.alpha
            beta = state.beta

            state.putChess x, y

            # zero windows search
            state.alpha = -alpha - epsilon
            state.beta = -alpha

            val = -@doSearch state

            # if alpha value is imporved
            # do complete re-search
            if val > alpha
              @nZeroWindowFail += 1
              state.alpha = -beta
              state.beta = -alpha
              val = -@doSearch state
            else
              @nZeroWindowCutoff += 1
          else
            state.putChess x, y
            val = -@doSearch state

          state.rollback()

          if val >= state.beta
            return val
          if val >= state.alpha
            state.alpha = val

    ret = state.alpha
    if not fliped
      state.missTurn()
      ret = -@doSearch state
      state.rollback()
    return ret

  search: (state) ->
    @doSearch state
    
  branchingFactor: (nState, depth) ->
    Math.pow(nState, 1.0 / depth)

  nextStep: (board, turn, settings) ->
    settings = {} if not settings?
    @settings = $.extend({}, @settingsDefault, settings)
    for key, val of @settings
      this[key] = val

    startTime = (new Date()).getTime()
    @nState = 0
    @depthMax = 0
    @nZeroWindowCutoff = 0
    @nZeroWindowFail = 0
    @killerTable = new KillerTable board
    bestVal = -infVal - 1
    for x in [0..@n-1]
      for y in [0..@n-1]
        if board.canPutChess(x, y, turn)
          state = new ReversiSearchState(board, turn)
          state.board.enableHistory = true
          state.putChess x, y

          stateCnt = @nState
          val = -@search state
          stateCnt = @nState - stateCnt

          console.log ["choice", x, y, val, stateCnt]
          if val > bestVal
            [bestX, bestY, bestVal] = [x, y, val]
            console.log ["bestChoiceUpdate", bestX, bestY, bestVal]
    endTime = (new Date()).getTime()
    console.log "stats: total node searched: #{@nState}"
    console.log "stats: search depth max: #{@depthMax}"
    console.log "stats: average branching factor: #{@branchingFactor @nState, @depthMax}"
    console.log "stats: search time: #{endTime - startTime}ms"
    console.log "stats: node per sec: #{@nState / ((endTime - startTime) / 1000.0)}"
    console.log "stats: zero window: cutoff #{@nZeroWindowCutoff}, fail #{@nZeroWindowFail}, "
    return null if bestVal is -infVal - 1
    return [bestX, bestY]

root.Reversi = Reversi
root.ReversiBoard = ReversiBoard
root.ReversiSearchState = ReversiSearchState
root.KillerTable = KillerTable
root.settings =
  range: range
  black: black
  white: white
  empty: empty
  chessSet: chessSet
# } end Reversi
