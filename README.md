# youtube-to-spotify-lua-
An application used to convert your youtube-playlist to your spotify-playlist.


## There are 2 Sections > Installation/Usage & Setting Up API KEYS
## Section 1: Installation On Unix/Linux Systems
I could not find a simple way to install luarocks on <ins>Windows</ins>,<br>
HOWEVER, You are recommended use WSL for luarocks installation instead, [WSL For Windows](https://medium.com/@sidsamanta/installing-wsl-in-windows-10-b6e8d04f5481)

### Requirements
* Lua
* Luarocks

### 1. Installing the required modules
  ```bash
    luarocks install cjson
    luarocks install lbase64
    luarocks install luasocket
    luarocks install luaossl
  ```
### 2. Running the actual code ( Finish Section 2 First )
  ```lua
    lua ./main.lua
  ```
## Section 2: Setting Up API KEYS

### 1. Set up Spotify For Developers Account
[Log In To Developers Using Your Spotify Account](https://developer.spotify.com/)
 ### 2. Open Dashboard and Create App
      Name your app, description as any name you like.
      For Redirect URIs > Add "http://localhost/" & "http://localhost:8080/" without quotation.
      Which API/SDKs are you planning to use? > Click "WEB API"
### 3. Click your app, and press settings(has purple borders)
  <img src="https://github.com/SaitoGH/youtube-to-spotify-lua-/assets/42116722/d9c13264-a897-41b5-b550-557369c9663b" width="500" height="350"><br>
        Get both the client id, and client secret and save them inside the .data file.<br>
        For your SPOTIFY_USER_ID, you may find in your account, it may be under username.
### 4. Get your Youtube API Key.
  For this step, you may refer > [Follow The Steps](https://blog.hubspot.com/website/how-to-get-youtube-api-key)
  Once you receive youtube api key credential, insert into the .data file.
### 5. Finish, you may try running the code again In Section 1.

## Q&A
<b>Why even bother doing this using lua?</b><br>
I did it for the purpose of experimenting what lua is capable of using my current knowledge.<br>
It was not meant for ease of use.
