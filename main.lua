local cjson = require("cjson")
local http = require("socket.http")
local url = require("socket.url")
local socket = require("socket")
local ltn12 = require("ltn12")
local digest = require("openssl.digest")
local mime = require("mime")
local base64 = require("base64")
local data_table = {
  ["id"] = nil,
  ["secret"] = nil,
  ["yt_key"] = nil,
  ["u_id"] = nil
}

function read_file() -- reads .data file
  local file = io.open(".data", "r")
  for line in file:lines() do
    local id = line:match("SPOTIFY_CLIENT_ID='(.-)'")
    if id then
      data_table["id"] = id
    end
    local secret = line:match("SPOTIFY_CLIENT_SECRET='(.-)'")
    if secret then
      data_table["secret"] = secret
    end
    local yt_key = line:match("YOUTUBE_API_KEY='(.-)'")
    if yt_key then
      data_table["yt_key"] = yt_key
    end
    local user_id = line:match("SPOTIFY_USER_ID='(.-)'")
    if user_id then
      data_table["u_id"] = user_id
    end
  end
  print(string.format("Received Client ID: %s\nReceived Client Secret ID: %s\nReceived User ID: %s", data_table["id"], data_table["secret"], data_table["u_id"]))
  file:close()
end


function get_token_client(client_id, client_secret)
  local uri = 'http://localhost:8080/'
  local code = get_auth_flow(client_id, uri) -- this returns code for access token
  assert(client_id and client_secret, "Invalid client ID or client secret")
  local respbody = {}
  local body = string.format("grant_type=%s&code=%s&redirect_uri=%s",
    url.escape("authorization_code"),
    url.escape(code),
    url.escape(uri)
  )
  local auth = base64.encode(client_id .. ":" .. client_secret)

  local result, rc, rheader, rstatus = http.request {
    method = "POST",
    url = "https://accounts.spotify.com/api/token",
    headers = {
        ["Authorization"] = "Basic " .. auth,
        ["Content-Type"] = "application/x-www-form-urlencoded",
        ["Content-Length"] = #body,
    },
    source = ltn12.source.string(body),
    sink = ltn12.sink.table(respbody)
  }
  print(result, rc, rheader, rstatus)
  respbody = table.concat(respbody)
  print(string.format("Received Access Token From %s (Available for an hour)", client_id))
  local decodedData = cjson.decode(respbody) -- a table
  print("Access Token: " .. decodedData['access_token'])
  print("Scope: " .. decodedData['scope'] )
  return decodedData['access_token']
end

function get_auth_flow(client_id, uri)
  local _data_table = {}
  local scope = 'playlist-modify-private playlist-modify-public';
  local authUrl = "https://accounts.spotify.com/authorize"
  --auth pkce section
  local function randStr(length)
    local _str = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~"
    local str = {}
    for i = 1, length do
        str[i] = _str:sub(math.random(#_str), math.random(#_str))
    end
    return table.concat(str)
  end
  local function build_query(params)
    local query_parts = {}
    for k, v in pairs(params) do
        table.insert(query_parts, k .. "=" .. url.escape(v))
    end
    return table.concat(query_parts, "&")
  end
 
  local codeVerifier = randStr(16)

  --Building the query
  local params = {
      response_type = "code",
      client_id = client_id,
      scope = scope,
      redirect_uri = uri
  }

  local fullUrl = authUrl .. "?" .. build_query(params)
  print("Authorization URL (Click Here & Come Back):", fullUrl)
  local server = assert(socket.bind("*", 8080)) -- no plans in changing the port 
  local client = server:accept()
  client:settimeout(10)
  local response = nil
  while true do
    local line, err = client:receive()
    if not err then
      local _, _, query_string = string.find(line, "%?([^%s]+)")
      _, _, response = string.find(query_string, "code=([^&]+)")
      break
    end
  end
  client:close()
  server:close()
  return response
end






--Gets all individual playlist data from youtube (unrelated to auth)
function getPlaylistHttpReq(yt_token) -- returns a json table with the titles
  local _GETplaylistTable, _playlistTable, playlistTable = {}, {}, {}
  io.write('Example (https://www.youtube.com/playlist?list=PLuIwWl_ig7fs55pKeLMUYky_52e5t4WaV)\n Take only whats after "=" : PLuIwWl_ig7fs55pKeLMUYky_52e5t4WaV\n')
  io.write('Give a youtube playlist ID:')
  local urllink = io.read()
  local url = string.format("https://www.googleapis.com/youtube/v3/playlistItems?playlistId=%s&part=snippet&fields=items(snippet(title,videoOwnerChannelTitle))&maxResults=50&key=%s", urllink, yt_token)
  local req = http.request {
    method = 'GET',
    url = url,
    sink = ltn12.sink.table(_GETplaylistTable)
  }
  _playlistTable = table.concat(_GETplaylistTable)
  local jsonTable = cjson.decode(_playlistTable)["items"]
  print("Playlist Collected From Youtube Playlist:")
  for i=1,#jsonTable do
    local artists = jsonTable[i]["snippet"]["videoOwnerChannelTitle"]
    artists = artists:gsub("%s-%-.+", "")
    table.insert(playlistTable, {["title"] = jsonTable[i]["snippet"]["title"], ["artist"] = artists})
    print(i, jsonTable[i]["snippet"]["title"], artists)
  end
  --this returns as an example = {ラグトレイン, Inabakumori}
  return playlistTable
end

--getSpotifyTracksReq is Under getAllPlaylistTrack
function getSpotifyTracksReq(token_client, title, artist)
  --This returns only 1 track which can be changed with local limit variable
  -- returns a json table
  assert(token_client, "Invalid spotify access token.")
  local limit = 1
  local artist = artist or ""
  title = url.escape(title)--escape title
  artist = url.escape(artist)--escape artist
  local local_token_url = string.format("Bearer %s", token_client)
  local _getURL = string.format('https://api.spotify.com/v1/search?q=%s%%20artist:%s&type=track&limit=%s', title, artist, limit)
  local _GETtrackdata = {}
  local function reqTrack(retry)
    if retry == true then
      _getURL = string.format('https://api.spotify.com/v1/search?q=%s&type=track&limit=%s', title, limit)
    end
    local req = http.request {
      method = 'GET',
      url = _getURL,
      sink = ltn12.sink.table(_GETtrackdata),
      headers = {
        ["Authorization"] = local_token_url,
      },
    }
    _GETtrackdata = cjson.decode(table.concat(_GETtrackdata))
  end
  reqTrack(false)
  
  --Retry with another method if not found
  if (next(_GETtrackdata["tracks"]["items"]) == nil) then
    _GETtrackdata = {}
    print("No tracks found, trying another method.")
    reqTrack(true)
  end

  return _GETtrackdata
end
function getAllPlaylistTrack(tablePlaylist, token)--return spotify PlaylistCollection = {songid, songuri, songlink}
  local _t = tablePlaylist or {}
  local _getPlaylistCollection = {}
  if not (next(_t) == nil) then
    print("Receiving Track Playlist Data")
    for k,v in pairs(_t) do
      print(k, v["title"])
      local _mt = getSpotifyTracksReq(token, v["title"], v["artist"])["tracks"]["items"][1]
      if (_mt) then
        print("Spotify ID: " .. _mt["id"])
        print("Spotify Link: " .. _mt["external_urls"]["spotify"])
        table.insert(_getPlaylistCollection, {["id"] = _mt["id"], ["uri"] = _mt["uri"], ["link"] = _mt["external_urls"]["spotify"]})
      else 
        print("Could not find song related to the title.")
      end
      print("-----------------------------------------------------------------------")
    end
  else 
    print("Given table was empty or invalid.")
  end
  return _getPlaylistCollection
end
--Inputs title, creates playlist (unrelated to auth), returns playlist id
function createSpotifyPlaylist(token_client, id)
  local _getPlaylistData = {}
  local title
  local local_token_url = string.format("Bearer %s", token_client)
  io.write("What would you like to name your playlist:")
  title = io.stdin:read()

  local url = "https://api.spotify.com/v1/users/" .. data_table["u_id"] .. "/playlists"
  local request_body = {name = title, description = "", public = false}
  local request_body_json = cjson.encode(request_body) -- Convert the table to JSON string
  local response = {}
  local result, rc, rheader, rstatus = http.request {
    method = 'POST',
    url = url,
    source = ltn12.source.string(request_body_json),
    headers = {
      ["Authorization"] = local_token_url,
      ["Content-Type"] = "application/json",
      ["Content-Length"] = #request_body_json
    },
    sink = ltn12.sink.table(response)
  }
  response = table.concat(response)
  if rc == 201 then
    print("Playlist Successfully Created")
    print("Playlist name: " .. title)
    print("Playlist public?: " .. tostring(request_body["public"]))
    print("Playlist desc: " .. request_body["description"])
  else 
    print("Playlist Creation Failed: " .. rstatus .. "\n Error Code: " .. rc)
  end
  return cjson.decode(response)["id"]
end

--Adds all the collected tracks to the playlist
function compileSpotifyPlaylist(token_client, playlistID, playlistCollection)
  local url = string.format("https://api.spotify.com/v1/playlists/%s/tracks", playlistID)
  local request_body = {}
  for k,v in pairs(playlistCollection) do
    table.insert(request_body, v["uri"])
  end
  local request_body_json = cjson.encode(request_body) 
  local result, rc, rheader, rstatus = http.request {
    method = 'POST',
    url = url,
    source = ltn12.source.string(request_body_json),
    headers = {
      ["Authorization"] = "Bearer " .. token_client,
      ["Content-Type"] = "application/json",
      ["Content-Length"] = #request_body_json
    },
    sink = ltn12.sink.file(io.stdout)
  }
  if rc == 201 then
    print("Success")
    print("All tracks has been added to the playlist.")
  else
    print("Failed")
    print("Tracks failed to be added to the playlist")
  end
end
read_file()

local token_client = get_token_client(data_table["id"], data_table["secret"])
local playlistTable = getPlaylistHttpReq(data_table["yt_key"])--PLuIPWl_iG7fs35pKeLMaYky_5qe0tWaSV
local convertablePlaylist =  getAllPlaylistTrack(playlistTable, token_client)
local playlistID = createSpotifyPlaylist(token_client, data_table["id"])
compileSpotifyPlaylist(token_client, playlistID, convertablePlaylist)