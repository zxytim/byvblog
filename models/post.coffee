'use continuation'
mongoose = require '../lib/mongoose'
translate = require '../lib/translate'
utils = require '../lib/utils'
config = require '../config'
marked = require 'marked'

contentSchema = new mongoose.Schema
  title: String
  contents: String
  language: String

postSchema = new mongoose.Schema
  guid:
    type: String
    index: true
    unique: true
  id:
    type: String
    index: true
    unique: true
  contents: [contentSchema]
  contentsFormat: String
  author: String
  postTime:
    type: Date
    index: true
  clicks:
    type: Number
    index: true
  tags:
    type: [String]
    index: true
  private:
    type: Boolean
    index: true
  list:
    type: Boolean
    index: true
  related: [String]

module.exports = Post = mongoose.model 'Post', postSchema

postSchema.pre 'save', (next) ->
  if not @postTime?
    @postTime = new Date
  if not @guid?
    @guid = utils.md5(@postTime.toString()).substr(0, 10)
  if not @clicks?
    @clicks = 0
  if not @private?
    @private = false
  if not @list?
    @list = false
  if not @clicks
    @clicks = 0
  next()

Post.getPosts = (conditions, page, pageSize, next) ->
  page = 1 if page < 1
  skip = (page - 1) * pageSize
  Post.find(conditions).skip(skip).limit(pageSize).sort('-postTime').exec next

Post.getPopularPosts = (count, next) ->
  Post.find({private:false, list:true}).limit(count).sort('-clicks').exec next

Post.getRecentPosts = (count, next) ->
  Post.getPosts {private:false, list:true}, 1, 5, next

Post.getArchive = (next) ->
  now = new Date
  cond = {private:false, list:true}
  #Get the oldest post
  Post.find(cond).limit(1).sort('postTime').exec obtain(oldest)
  if oldest.length is 0
    oldest = now
  else
    oldest = oldest[0].postTime
  
  #Generate all months bewteen oldest day until now
  months = []
  if now.getFullYear() is oldest.getFullYear()
    year = now.getFullYear()
    month = oldest.getMonth()
    while month <= now.getMonth()
      months.push new Date(year, month, 1)
      month++
  else
    year = oldest.getFullYear()
    month = oldest.getMonth()
    while month < 12
      months.push new Date(year, month, 1)
      month++
    year++
    while year < now.getFullYear()
      month = 0
      while month < 12
        months.push new Date(year, month, 1)
        month++
      year++
    month = 0
    while month <= now.getMonth()
      months.push new Date(year, month, 1)
      month++
  
  #Get post count of each month
  archives = []
  for i, start of months
    i = parseInt(i)
    end = months[i + 1]
    cond =
      private:false
      list:true
      postTime:
        $gte: start
    if end?
      cond.postTime.$lt = end
    Post.count cond, obtain(count)
    if count > 0
      archives.unshift
        month: start
        count: count
  next null, archives

Post.getTags = (next) ->
  Post.find {private:false}, obtain(posts)
  tags = {}
  for post in posts
    for tag in post.tags
      tags[tag] ?= 0
      tags[tag]++
  result = []
  for tag in Object.keys(tags)
    result.push
      tag: tag
      count: tags[tag]
  next null, result

parseTags = (tags) ->
  return [] if not tags
  tags = tags.split ','
  for i of tags
    tags[i] = tags[i].trim()
  tags

parseContents = (contents) ->
  return [] if not contents
  filtered = []
  for lang, content of contents
    if content.title
      content.language = lang
      filtered.push content
  filtered

Post.newPost = (rawPost, author, next) ->
  post = new Post
  post.author = author
  post.modify rawPost, next

Post.render = (posts, language, next) ->
  try
    for post, i in posts
      post.render language, obtain(posts[i])
    next null, posts
  catch err
    next err

Post::modify = (rawPost, next) ->
  @id = rawPost.id
  @tags = parseTags rawPost.tags
  @clicks = rawPost.clicks
  @private = rawPost.private
  @list = rawPost.list
  @contentsFormat = rawPost.contentsFormat
  @contents = parseContents rawPost.contents
  if not @id or not @contents
    return next new Error('Required fields')
  @save cont(err, post)
  next err, post

Post::getContentsByLanguage = (language) ->
  for content in @contents
    if content.language is language
      return content
  null

Post::render = (language, next) ->
  self = this
  post = @toObject()
  rendered = false

  if language
    content = self.getContentsByLanguage language
    post.language = language
  else
    content = self.contents[0]
    post.language = self.contents[0].language

  if content
    post.title = content.title
    post.contents = content.contents
    rendered = true

  if not rendered
    if language is 'zhs'
      content = self.getContentsByLanguage 'zht'
      if content
        translate.zhtToZhs content.title, obtain(post.title)
        translate.zhtToZhs content.contents, obtain(post.contents)
        post.contents = post.contents
        post.converted = 'opencc'
        rendered = true
    else if language is 'zht'
      content = self.getContentsByLanguage 'zhs'
      if content
        translate.zhsToZht content.title, obtain(post.title)
        translate.zhsToZht content.contents, obtain(post.contents)
        post.contents = post.contents
        post.converted = 'opencc'
        rendered = true
    else if language is 'en'
      translateLink = 'http://translate.google.com/translate?act=url&hl=en&ie=UTF8sl=auto&tl=en&u=' + config.site.url + encodeURIComponent(post.id)
      translateTip = 'This post is written in Chinese. If you have trouble reading it, please use [Google Translate](' + translateLink + ')\n\n'
      post.title = self.contents[0].title
      post.contents = translateTip + self.contents[0].contents
      rendered = true
  
  if not rendered
    post.converted = 'translate'
    post.title = 'Not implemented'
    post.contents = 'Not implemented'
    #TODO google translate API

  if self.contentsFormat is 'markdown'
    post.contents = marked post.contents
  next null, post

Post::relatedPosts = (next) ->
  self = this
  if config.options.relatedPostsFast
    return self.relatedPostsFast next
  
  relatedPosts = []
  for guid in self.related
    Post.findOne {guid: guid}, obtain(post)
    if post?
      post.title = post.contents[0].title
      relatedPosts.push post
      if relatedPosts.length is config.options.relatedPosts
        break
  next null, relatedPosts

Post::relatedPostsFast = (next) ->
  self = this
  
  potRelatedPosts = {}
  for tag in self.tags
    Post.find {tags: tag}, obtain(posts)
    for post in posts
      potRelatedPosts[post.guid] = post
  
  relatedPosts = []
  for guid in Object.keys(potRelatedPosts)
    post = potRelatedPosts[guid]
    post.title = post.contents[0].title
    relatedPosts.push post
    if relatedPosts.length is config.options.relatedPosts
      break
  
  next null, relatedPosts
