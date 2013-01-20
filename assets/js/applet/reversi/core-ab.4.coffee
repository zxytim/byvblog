
root = exports ? this
if require?
  $ = require 'jquery'
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
    @n = lines.length
    for x in range @n
      this[x] = []
      for y in range @n
        this[x][y] = lines[y][x].charCodeAt(0) - '0'.charCodeAt(0)

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
    [@nMyChess, @nOpChess] = @board.getParams @turn
    @nMissedTurn = 0

  missTurn: () ->
    @history.push [0, @alpha, @beta, @turn, @nMyChess, @nOpChess, @nMissedTurn]
    @nMissedTurn += 1
    @turn = flipTurn @turn
    [@alpha, @beta] = [-@beta, -@alpha]
    [@nMyChess, @nOpChess] = [@nOpChess, @nMyChess]

  putChess: (x, y) ->
    @history.push [1, @alpha, @beta, @turn, @nMyChess, @nOpChess, @nMissedTurn]
    @board.putChess x, y, @turn
    @turn = flipTurn @turn
    @step += 1
    @depth += 1
    @nMissedTurn = 0
    [@alpha, @beta] = [-@beta, -@alpha]
    [@nMyChess, @nOpChess] = @board.getParams @turn

  rollback: () ->
    [type, @alpha, @beta, @turn, @nMyChess, @nOpChess, @nMissedTurn] = @history.pop()
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

class Reversi
  constructor: (n) ->
    @n = n

    # settings are exposed to class variable
    # before search
    @settings = {}
    @settingsDefault =
      searchDepthMax: 4
      searchTimeMax: 3 # in second

    @nState = 0
    @depthMax = 0

  init: () ->
    #TODO

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

  # common variable shared:
  #   @hashTable
  #   @killerTable
  search: (state) ->
    @nState += 1
    @depthMax = state.depth if state.depth > @depthMax
    if state.shouldEvaluate(@searchDepthMax)
      return @evaluateState state

    minVal = infVal - 1
    other = flipTurn turn
    turn = state.turn
    for x in [0..@n-1] by 1
      for y in [0..@n-1] by 1
          if state.board.canPutChess x, y, turn

            s0 = state.toString()
            state.putChess x, y
            val = @search state
            state.rollback()
            minVal = val if val < minVal
            s1 = state.toString()
            assert(s0 is s1, "s0 is s1")

    if minVal is infVal - 1
      s0 = state.toString()
      state.missTurn()
      minVal = @search state
      state.rollback()
      s1 = state.toString()
      assert(s0 is s1, "s0 is s1")
    return -minVal
    
  nextStep: (board, turn, settings) ->
    settings = {} if not settings?
    @settings = $.extend({}, @settingsDefault, settings)
    for key, val of @settings
      this[key] = val

    @nState = 0
    @depthMax = 0
    bestVal = -infVal - 1
    for x in [0..@n-1]
      for y in [0..@n-1]
        if board.canPutChess(x, y, turn)
          state = new ReversiSearchState(board, turn)
          state.board.enableHistory = true
          state.putChess x, y
          val = -@search state
          console.log ["choice", x, y, val]
          if val > bestVal
            [bestX, bestY, bestVal] = [x, y, val]
            console.log ["bestChoiceUpdate", bestX, bestY, bestVal]
    console.log "total state searched: #{@nState}"
    console.log "search depth max: #{@depthMax}"
    return null if bestVal is -infVal - 1
    return [bestX, bestY]

root.Reversi = Reversi
root.ReversiBoard = ReversiBoard
root.ReversiSearchState = ReversiSearchState
root.settings =
  range: range
  black: black
  white: white
  empty: empty
  chessSet: chessSet
# } end Reversi
