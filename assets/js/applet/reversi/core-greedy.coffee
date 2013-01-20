
root = exports ? this
if require?
  $ = require 'jquery'
  
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
# used in where efficiency is of no importance
range = () ->
  return [] if arguments.length == 0
  return [0..arguments[0] - 1] if arguments.length == 1
  return [arguments[0]..arguments[1] - 1]

# defines
[empty, white, black] = [0, 1, 2]
chessSet = [white, black]

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

  # assume checked
  putChess: (x, y, type) ->
    #return false if x < 0 or x >= @n or y < 0 or y >= @n
    #return false if this[x][y] not empty
    this[x][y] = type
    for [dx, dy] in @dirs
      [tx, ty] = [x + dx, y + dy]
      continue if not @inBoard tx, ty
      continue if this[tx][ty] is empty
      continue if this[tx][ty] is type
      tx += dx; ty += dy
      other = @flipTurn type
      while (@inBoard tx, ty) and this[tx][ty] is other
        tx += dx; ty += dy

      if (@inBoard tx, ty) and this[tx][ty] is type
        # this way is valid
        while tx isnt x or ty isnt y
          this[tx][ty] = type
          tx -= dx; ty -= dy

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
      other = @flipTurn type
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

  print: () ->
    str = ""
    for y in range @n
      for x in range @n
        str += "#{this[x][y]}"
      str += "\n"
    str
    console.log str

  hint: (type) ->
    ret = []
    for x in range @n
      for y in range @n
        if @canPutChess x, y
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
  # board

class Reversi
  constructor: (n) ->
    @n = n

    # settings are exposed to class variable
    # before search
    @settings = {}
    @settingsDefault =
      searchDepthMax: 6
      searchTimeMax: 3 # in second

  init: () ->


  evaluateState: (board, turn, step, nMyChess, nOpChess) ->
    return -infVal if nMyChess is 0
    return infVal if nOpChess is 0

    ret = 0
    for i in [0..@n-1] by 1
      for j in [0..@n-1] by 1
        c = board[i][j]
        continue if c is empty
        ret += (if c is turn then 1 else -1)
    return ret

  # common variable shared:
  #   @hashTable
  #   @killerTable
  search: (board, turn, nMyChess, nOpChess, alpha, beta, depth) ->
    #if nMyChess is 0 or nOpChess is 0 or depth is @searchDepthMax
    return @evaluateState board, turn, nMyChess, nOpChess
    
  nextStep: (board, turn, settings) ->
    @settings = $.extend({}, @settingsDefault, settings)
    for key, val of @settings
      this.key = val

    bestVal = -infVal
    for x in [0..@n-1]
      for y in [0..@n-1]
        if board.canPutChess(x, y, turn)
          [nMyChess, nOpChess] = board.getParams turn
          newBoard = deepCopy board
          newBoard.putChess x, y, turn
          val = @search(newBoard, turn, nMyChess, nOpChess, -infVal, +infVal, 0)
          console.log ["choice", x, y, val]
          if val > bestVal
            [bestX, bestY, bestVal] = [x, y, val]
            console.log ["bestChoiceUpdate", bestX, bestY, bestVal]
    return null if bestVal is -infVal
    return [bestX, bestY]

root.Reversi = Reversi
root.ReversiBoard = ReversiBoard
root.settings =
  range: range
  black: black
  white: white
  empty: empty
  chessSet: chessSet
# } end Reversi
