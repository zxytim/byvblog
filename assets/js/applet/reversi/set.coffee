class Set
  constructor: () ->
    @content = {}

  insert: (key) ->
    @content[key] = true

  remove: (key) ->
    delete @content[key]
  
  contains: (key) ->
    key in @content

root = exports ? this
root.Set = Set
