# wordfinder

## Prerequisites

These non-core modules must be installed:
* `Mojolicious::Lite`
* `Readonly`
* `LCS::Tiny`
* `List::MoreUtils`

## How to use

On one terminal, run the web server:
```
$ morbo wordfinder.pl
```

By default, it will run on port 3000. If you want to change it to, say, port 7860:
```
$ morbo -l "http://*:7860" wordfinder.pl
```

Open another terminal, and try these:
* Pinging. This will just return OK (HTTP code 200; content type: `text/plain`):
  ```
  $ curl http://127.0.0.1:7860/ping
  OK
  ```
* Find words in dictionary (the default is `/usr/share/dict/words`. Change in `wordfinder.conf`) and get the result as a JSON object (content type: `application/json`; note that the result depends on the content of the dictionary used):
  ```
  $ curl http://127.0.0.1:7860/wordfinder/dgo
  ["D","G","God","O","Od","Og","d","do","dog","g","go","god","o","od"]
  ```
