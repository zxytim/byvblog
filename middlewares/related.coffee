'use continuation'
Post = require('../models/post')
config = require('../config')

Segment = require('node-segment').Segment
segment = new Segment()
segment.useDefault()
segment.loadDict('dict.txt')
segment.loadDict('dict2.txt')
segment.loadDict('names.txt')
segment.loadDict('stopword.txt')
segment.loadDict('synonym.txt')
segment.loadDict('wildcard.txt')

segmentation = (post) ->
  segments = segment.doSegment(post.contents[0].contents)
  console.log segments
  words = {}
  for seg in segments
    words[seg.w] ?= 0
    words[seg.w]++
  post.words = words

similarity = (post1, post2) ->
  if not post1.words?
    segmentation post1
  if not post2.words?
    segmentation post2
  
  dist = 0
  calc = {}
  calcDist = (from) ->
    for word in Object.keys(from)
      if not calc[word]
        calc[word] = true
        p1 = post1.words[word]
        p2 = post2.words[word]
        p1 ?= 0
        p2 ?= 0
        d = (p1 - p2) * (p1 - p2)
        dist += d
  calcDist post1.words
  calcDist post2.words
  
  return 10000000 / dist

usePostMap = false
postMap = {}
exports.relatedPosts = (post, count, next) ->
  selfPost = post.toObject()
  #Get posts which have at least one common tag with selfPost
  potRelatedPosts = {}
  for tag in selfPost.tags
    Post.find {tags: tag, private:false, list:true}, obtain(posts)
    for post in posts
      potRelatedPosts[post.guid] = post.toObject()
  posts = []
  for guid in Object.keys(potRelatedPosts)
    if usePostMap and postMap[guid]
      post = postMap[guid]
    else
      post = potRelatedPosts[guid]
      postMap[guid] = post if usePostMap
    posts.push post
  #Calculate similarity
  targets = []
  for target in posts
    if selfPost.guid isnt target.guid
      target.similarity = similarity(selfPost, target)
      targets.push target
  targets.sort (a, b) ->
    if a.similarity > b.similarity then -1 else 1
  next null, targets.slice(0, count)

exports.updateRelatedPosts = (next) ->
  usePostMap = true
  Post.find {}, obtain(posts)
  for post in posts
    console.log post.id, post.contents[0].title
    relatedPosts = []
    exports.relatedPosts post, config.options.relatedPosts, obtain(relatedPosts)
    post.related = []
    for p in relatedPosts
      post.related.push p.guid
    post.save obtain()
  usePostMap = false
  postMap = {}
  next null
