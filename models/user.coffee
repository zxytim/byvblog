'use continuation'
mongoose = require '../lib/mongoose'

passwordHash = (password) ->
  md5 = (str) ->
    (require 'crypto').createHash('md5').update(str).digest('hex')
  sha512 = (str) ->
    (require 'crypto').createHash('sha512').update(str).digest('hex')
  md5(sha512(md5(password)))

userSchema = new mongoose.Schema
  name:
    type: String
    index: true
    unique: true
  password: String

userSchema.pre 'save', (next) ->
  this.password = passwordHash this.password
  next()

module.exports = User = mongoose.model 'User', userSchema

User.passwordHash = passwordHash

User.authenticate = (user, next) ->
  return next 'Invalid Username' if not user?
  User.findOne {name:user.name}, cont(err, dbUser)
  return next err if err
  return next 'Invalid Username' if not dbUser?
  if (passwordHash user.password) != dbUser.password
    next 'Invalid Password'
  else
    next null, dbUser.toObject()
