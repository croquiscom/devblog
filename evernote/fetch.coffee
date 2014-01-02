async = require 'async'
{Evernote} = require 'evernote'
fs = require 'fs'

dir = "#{__dirname}/.evernote_cache"
oauthAccessToken = ''
notebookGuid = '9dacde4e-3cb0-4560-8cda-fd5d6e416564'

try fs.mkdirSync dir

seqNums = {}
tags = {}

updateSeqNum = (guid, seqNum) ->
  seqNums[guid] = seqNum if not seqNums[guid] or seqNums[guid] < seqNum

readSeqNums = ->
  files = fs.readdirSync dir
  for file in files
    if /(.*):(.*)\.enml/.test file
      updateSeqNum RegExp.$1, Number(RegExp.$2)
readSeqNums()

noteStore = new Evernote.Client(token: oauthAccessToken, sandbox: false).getNoteStore()

getNoteContent = (note, callback) ->
  console.log 'Get note: ' + note.title + ',' + note.guid + ':' + note.updateSequenceNum
  noteStore.getNoteContent note.guid, (error, content) ->
    console.log 'getNoteContent: ' + JSON.stringify(error) if error
    callback content

getNote = (note, callback) ->
  filename = "#{dir}/#{note.guid}:#{note.updateSequenceNum}.enml"
  return callback true if fs.existsSync filename
  getNoteContent note, (content) ->
    return callback false if not content
    fs.writeFileSync filename, content
    callback true

getAllNotes = (callback) ->
  filter = new Evernote.NoteFilter notebookGuid: notebookGuid
  result_spec = new Evernote.NotesMetadataResultSpec includeTitle: true, includeCreated: true, includeUpdated: true, includeUpdateSequenceNum: true, includeTagGuids: true
  noteStore.findNotesMetadata filter, 0, 10000, result_spec, (error, response) ->
    return callback error if error
    notes = response.notes
    async.forEachSeries notes, (note, next) ->
      return next null if seqNums[note.guid] is note.updateSequenceNum
      getNote note, (success) ->
        return next null if not success
    , (error) ->
      callback error, notes

getTag = (tagGuid, callback) ->
  return callback null, tags[tagGuid] if tags[tagGuid]
  noteStore.getTag tagGuid, (error, tag) ->
    return callback null if error
    callback null, tags[tagGuid] = tag.name

cutBeforeHR = (content) ->
  hr_pos = content.indexOf '<hr/>'
  return ['', content] if hr_pos<0

  elements = content.substr(0, hr_pos).split('<')[1..].reverse()
  elements_meta = []
  elements_content = []
  depth = 1
  all_meta = false
  for element in elements
    if element[0] is '/'
      depth++
    else
      depth--
    if all_meta or depth > 0
      elements_meta.push element
    else
      elements_content.push element
    all_meta = true if depth is 0

  meta_str = '<'+elements_meta.reverse().join('<')
  content = '<'+elements_content.reverse().join('<') + content.substr(hr_pos+5)

  return [meta_str, content]

parseMeta = (meta_str) ->
  meta = {}
  meta_str = meta_str.replace /<[^>]*>/g, '\n'
  for line in meta_str.split '\n'
    if /(.*):(.*)/.test line
      meta[RegExp.$1.trim()] = RegExp.$2.trim()
  return meta

readNote = (filename) ->
  content = fs.readFileSync filename, 'utf-8'
  /<en-note>(.*)<\/en-note>/.test content
  [meta_str, content] = cutBeforeHR RegExp.$1
  meta = parseMeta meta_str
  return [meta, content]

datePad = (num) ->
  return '0' + num if num<10
  return num

getCountForDate = (path, date) ->
  count = 1
  files = fs.readdirSync path
  for file in files
    count++ if file.substr(0, date.length) is date
  return count

writePost = (note, tags, meta, content) ->
  lang_tags = tags.filter (tag) -> tag.substr(0,5) is 'lang:'
  lang = lang_tags[0]?.substr 5
  return if not lang
  tags = tags.filter (tag) -> tag.substr(0,5) isnt 'lang:'

  front = []
  front.push '---'
  front.push 'layout: post.' + meta.author
  front.push 'title: ' + note.title
  front.push 'category: ' + meta.category
  front.push 'tags: [' + tags.join(', ') + ']'
  front.push '---'
  front.push ''
  content = front.join('\n') + content

  created = new Date(note.created)
  path = "../#{lang}/_posts"
  date = "#{created.getFullYear()}-#{datePad created.getMonth()+1}-#{datePad created.getDate()}"
  count = getCountForDate path, date
  filename = "#{path}/#{date}-#{count}-#{meta.url_path.replace /\ /g, '-'}.html"

  fs.writeFileSync filename, content

getAllNotes (error, notes) ->
  notes.sort (a, b) -> return a.created - b.created
  async.forEachSeries notes, (note, next) ->
    filename = "#{dir}/#{note.guid}:#{note.updateSequenceNum}.enml"
    return next null if not fs.existsSync filename
    async.map note.tagGuids, getTag, (error, tags) ->
      [meta, content] = readNote filename
      writePost note, tags, meta, content
      next null
  , (error) ->
