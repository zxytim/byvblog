'use continuation'

exports.index = (req, res, next) ->
  code = "#include <cstdio>\n\nint main()\n{\n  return 0;\n}\n"
  res.send "<script type='text/javascript' src='/js/underscore-min.js'></script><script type='text/javascript' src='/js/jquery-1.8.2.js'></script><pre class='code'>#{code}</pre><code>#{code}</code><pre>&</pre>"
